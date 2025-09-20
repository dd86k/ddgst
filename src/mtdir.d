/// Multithreaded-capable dirEntries.
///
/// This adds multithreading capability to dirEntries by sending work to a thread pool.
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module mtdir;

import std.concurrency;
import std.file;
import std.path : globMatch, baseName;
import std.parallelism : totalCPUs;
import core.thread.osthread : Thread;
import std.datetime : Duration, dur;

struct MTDirConfig
{
    /// Function called before thread processes entries.
    ///
    /// Accepts user object (must be on heap).
    immutable(void)* function(immutable(void)*) fninit;
    /// Function called when processing a directory entry.
    /// 
    void function(DirEntry, immutable(void)*, immutable(void)*) fnentry;
    /// Spanning mode used in dirEntries.
    SpanMode mode;
    /// Follow symlinks, parameter used in dirEntries.
    bool follow = true;
    /// Size of mailbox for each thread.
    int mailboxSize = 2;
    /// Timeout when reaching end of thread pool.
    Duration timeout = dur!"msecs"(500);
}

struct MTDirStats
{
    long entries;
}

/// Start a multithreaded dirEntries instance.
/// Note: Setting threads to 1 chooses the simpler, non-threaded implementation.
/// Params:
///     path = Directory path,
///     pattern = Glob pattern to match against file. Optional.
///     config = Configuration.
///     data = User data, must be heap-allocated.
///     threads = Amount of threads. 0 being automatic (total-1).
MTDirStats mtdirEntries(string path, string pattern, MTDirConfig config, immutable(void) *data, int threads = 0)
{
    import std.exception : enforce;
    
    enforce(path, "Path is undefined");
    enforce(config.fninit, "config.fninit is undefined");
    enforce(config.fnentry, "config.fnentry is undefined");
    
    // If no count specified, get total cores available.
    if (threads == 0)
        threads = totalCPUs;
    
    // If threads=0 or totalCPUs=0 (never), throw
    enforce(threads > 0, "Thread count needs to be positive");
    
    long total; // total entry count
    
    // If there's only one thread specified or if system has one core, run normal loop
    if (threads == 1)
    {
        immutable(void)* uobj = config.fninit(data);
        foreach (DirEntry entry; dirEntries(path, config.mode, config.follow))
        {
            if (pattern && globMatch(baseName(entry.name), pattern) == false)
                continue;
            ++total;
            config.fnentry(entry, uobj, data);
        }
        return MTDirStats(total);
    }
    
    // NOTE: Thread count & master thread
    //       It's dishonest to decrease the thread count, even when worried of the caller
    //       being saturated. That's just false, it's already detached from the workload.
    
    // Spawn n threads and assign them their queue size.
    scope pool = new Tid[threads];
    for (int i; i < threads; ++i)
    {
        Tid tid = spawn(&mtdirWorker, thisTid, config.fnentry, config.fninit(data), data);
        setMaxMailboxSize(tid, config.mailboxSize, OnCrowding.throwException);
        pool[i] = tid;
    }
    
    // Send every thread a message to work on.
    int tidx; // Current thread index
    foreach (DirEntry entry; dirEntries(path, config.mode, config.follow))
    {
        // Reimplement globbing
        if (pattern && globMatch(baseName(entry.name), pattern) == false)
            continue;
        ++total;
    Lretry:
        try send(pool[tidx], MsgEntry(entry));
        catch (MailboxFull)
        {
            // Mailbox full, try another try
            if (++tidx >= threads)
            {
                tidx = 0;
                // Since this is the end of the list, wait for a little,
                // maybe a thread will have some room again soon.
                Thread.sleep(config.timeout);
            }
            goto Lretry;
        }
        // Select next thread, and wrap if out of bound
        if (++tidx >= threads) tidx = 0;
    }
    
    // At this point, dirEntries is done sending entries and we need
    // to tell each thread that our work is done.
    // To do that, we change the strategy from Throw to Block,
    // then send the Done message. If it's full, we'll just wait,
    // we're already doing that.
    //
    // This work is required to avoid exceptions, when the program
    // stops but the worker threads are still doing work.
    foreach (ref tid; pool)
    {
        setMaxMailboxSize(tid, config.mailboxSize, OnCrowding.block);
        send(tid, MsgDone());
    }
    foreach (ref tid; pool)
        receiveOnly!MsgDoneAck;
    
    return MTDirStats(total);
}

private:

struct MsgEntry
{
    DirEntry entry;
}
struct MsgDone {}
struct MsgDoneAck {}

void mtdirWorker(Tid parentTid,
    void function(DirEntry, immutable(void)*, immutable(void*)) fnuser,
    immutable(void) *init,
    immutable(void) *data)
{
    bool working = true;
    while (working) receive(
        (MsgEntry msg) {
            fnuser(msg.entry, init, data);
        },
        (MsgDone msg) {
            send(parentTid, MsgDoneAck());
            // Forgot why I used a book and not a break, keep it
            working = false;
        }
    );
}
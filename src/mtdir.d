/// Multithreaded-capable dirEntries.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module mtdir;

import std.concurrency;
import std.file;
import std.path : globMatch, baseName;
import std.parallelism : totalCPUs;

//TODO: Find a way to construct dirEntries iterator.
//      Can't access DirIterator.this, can't re-use FilterResults template,
//      can't access DirIteratorImpl, etc.
//      dirEntries with pattern doesn't check if pattern is valid...
//      Kind of really silly, don't want to recreate dirEntries.
//      Defined as: bool f(DirEntry de) { return globMatch(baseName(de.name), pattern); }
//      So, if the implementation has a pattern, match it manually.
//      It doesn't seem to exclude directories in matching, odd?
//TODO: Consider returning statistics (e.g., files/folders processed)

/// Start a multithreaded dirEntries instance.
/// Note: Setting threads to 1 chooses the simpler, non-threaded implementation.
/// Params:
///   path = Directory path,
///   pattern = Glob pattern to match against file. Optional.
///   mode = Span mode.
///   follow = Follow symbolic links if set to true.
///   fnspawn = Callback initiation function that will be called per-thread.
///   fnentry = Callback function that will be called per-entry.
///   threads = Size of thread pool. Defaults to totalCPUs minus one.
///   mailboxSize = Size of mailbox for each thread. Defaults to five.
void dirEntriesMT(string path, string pattern, SpanMode mode, bool follow,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry,
    int threads = 0, int mailboxSize = 5)
{
    if (path == null)
        throw new Exception("Path is not defined");
    if (fnspawn == null)
        throw new Exception("fnspawn is not defined");
    if (fnentry == null)
        throw new Exception("fnentry is not defined");
    
    if (threads == 1)
    {
        dirEntriesSTImpl(path, pattern, mode, follow, fnspawn, fnentry);
        return;
    }
    
    dirEntriesMTImpl(path, pattern, mode, follow,
        fnspawn, fnentry,
        threads <= 0 ? totalCPUs-1 : threads,
        mailboxSize);
}

private:

// When threads=1 is specified
void dirEntriesSTImpl(string path, string pattern, SpanMode mode, bool follow,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry)
{
    immutable(void)* uobj = fnspawn();
    foreach (DirEntry entry; dirEntries(path, mode, follow))
    {
        if (pattern && globMatch(baseName(entry.name), pattern) == false)
            continue;
        fnentry(entry, uobj);
    }
}

// When threads=0 or threads>1 is specified
void dirEntriesMTImpl(string path, string pattern, SpanMode mode, bool followLinks,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry,
    int threads, int mailboxSize)
{
    // Spawn n threads and assign them a queue size of 10.
    // 10 because if we work on millions of file paths,
    // the stack might suffer at higher count.
    scope pool = new Tid[threads];
    for (int i; i < threads; ++i)
    {
        Tid tid = spawn(&dirEntriesMTWorker, thisTid, fnentry, fnspawn());
        // NOTE: About OnCrowding
        //       .ignore is a little suspicious, as at the end of the entries,
        //       a thread's mailbox might be full, and ignore MsgDone messages.
        setMaxMailboxSize(tid, mailboxSize, OnCrowding.block);
        pool[i] = tid;
    }
    
    // Send every thread a message to work on.
    int cur; // Current thread index
    foreach (DirEntry entry; dirEntries(path, mode, followLinks))
    {
        if (pattern && globMatch(baseName(entry.name), pattern) == false)
            continue;
        send(pool[cur], MsgEntry(entry));
        if (++cur >= threads) cur = 0;
    }
    
    // NOTE: Done/Ack messages are required to avoid an exception
    //       where the parent thread is terminated before the worker threads.
    // Push cancel request at the end of the queue.
    foreach (ref tid; pool)
    {
        send(tid, MsgDone());
    }
    // Wait for confirmation, this is to avoid this thread
    // to finish before their children
    foreach (ref tid; pool)
    {
        receiveOnly!MsgDoneAck;
    }
}

struct MsgEntry
{
    DirEntry entry;
}
struct MsgDone {}
struct MsgDoneAck {}

void dirEntriesMTWorker(Tid parentTid,
    void function(DirEntry, immutable(void)*) fnuser,
    immutable(void) *uobj)
{
    bool cont = true;
    while (cont)
    {
        receive(
            (MsgEntry msg) {
                fnuser(msg.entry, uobj);
            },
            (MsgDone msg) {
                send(parentTid, MsgDoneAck());
                cont = false;
            }
        );
    }
}
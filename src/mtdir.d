/// Multithreaded-capable dirEntries.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module mtdir;

import std.file;
import std.concurrency;
import std.parallelism : totalCPUs;

// TODO: Thread management
//        0 threads -> alloc maxcores-1 threads
//        1 thread  -> ignore and use single-threaded implementation
//       >1 threads -> alloc n threads
void dirEntriesMulti(string path, SpanMode mode, bool followLinks,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry,
    int threads = 0)
{
    if (path == null)
        throw new Exception("Path is not defined");
    if (fnspawn == null)
        throw new Exception("fnspawn is not defined");
    if (fnentry == null)
        throw new Exception("fnentry is not defined");
    
    if (threads == 1)
    {
        dirEntriesSingleImpl(path, mode, followLinks, fnspawn, fnentry);
        return;
    }
    
    dirEntriesMultiImpl(path, mode, followLinks,
        fnspawn, fnentry,
        threads <= 0 ? totalCPUs-1 : threads);
}

// When threads=1 is specified
private
void dirEntriesSingleImpl(string path, SpanMode mode, bool followLinks,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry)
{
    immutable(void)* uobj = fnspawn();
    foreach (DirEntry entry; dirEntries(path, mode, followLinks))
    {
        fnentry(entry, uobj);
    }
}

private
void dirEntriesMultiImpl(string path, SpanMode mode, bool followLinks,
    immutable(void)* function() fnspawn,
    void function(DirEntry, immutable(void)*) fnentry,
    int threads)
{
    // Spawn n threads and assign them a queue size of 10.
    // 10 because if we work on millions of file paths,
    // the stack might suffer at higher count.
    scope pool = new Tid[threads];
    for (int i; i < threads; ++i)
    {
        Tid tid = spawn(&dirEntriesMultiWorker, thisTid, fnentry, fnspawn());
        setMaxMailboxSize(tid, 10, OnCrowding.ignore);
        pool[i] = tid;
    }
    
    // Send every thread a message to work on.
    int cur;
    foreach (entry; dirEntries(path, mode, followLinks))
    {
        send(pool[cur], MessageNew(entry));
        if (++cur >= threads) cur = 0;
    }
    
    // Push cancel request at the end of the queue.
    foreach (ref tid; pool)
    {
        send(tid, MessageCancelReq());
    }
    // Wait for confirmation, this is to avoid this thread
    // to finish before their children
    foreach (ref tid; pool)
    {
        receiveOnly!MessageCancelled;
    }
}

private
struct MessageNew
{
    DirEntry entry;
}
private
struct MessageCancelReq
{
    
}
private
struct MessageCancelled
{
    
}

private
void dirEntriesMultiWorker(Tid parentTid,
    void function(DirEntry, immutable(void)*) fnuser,
    immutable(void) *uobj)
{
    bool cont = true;
    while (cont)
    {
        receive(
            (MessageNew msg) {
                fnuser(msg.entry, uobj);
            },
            (MessageCancelReq msg) {
                send(parentTid, MessageCancelled());
                cont = false;
            }
        );
    }
}
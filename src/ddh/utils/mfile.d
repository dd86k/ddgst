module ddh.utils.mfile;

//version = MFILE;

version (MFILE):

import std.conv, std.exception, std.stdio;
import std.file;
import std.path;
import std.string;
import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;

import std.internal.cstring;

version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.winnt;
    import std.utf;
    import std.windows.syserror;
}
else version (Posix)
{
    import core.sys.posix.fcntl;
    import core.sys.posix.sys.mman;
    import core.sys.posix.sys.stat;
    import core.sys.posix.unistd;
}
else
{
    static assert(0, "MemFile not supported for this system");
}

/// Read-only optimized MmFile structure
struct MFile
{
	this(string path)
	{
		open(path);
	}
	
	version (linux)
	void open(string path)
	{
		flags = MAP_SHARED;
		prot = PROT_READ;
		oflag = O_RDONLY;
		fmode = 0;

		fd = fildes;

		// Adjust size
		stat_t statbuf = void;
		errnoEnforce(fstat(fd, &statbuf) == 0);
		if (prot & PROT_WRITE && size > statbuf.st_size)
		{
			// Need to make the file size bytes big
			lseek(fd, cast(off_t)(size - 1), SEEK_SET);
			char c = 0;
			core.sys.posix.unistd.write(fd, &c, 1);
		}
		else if (prot & PROT_READ && size == 0)
		size = statbuf.st_size;
		this.size = size;

		// Map the file into memory!
		size_t initial_map = (window && 2*window<size)
		? 2*window : cast(size_t) size;
		void* p = mmap(address, initial_map, prot, flags, fd, 0);
		if (p == MAP_FAILED)
			errnoEnforce(false, "Could not map file into memory");
		data = p[0 .. initial_map];
	}
	
	version (Windows)
	void open(string path)
	{
	}
	
	/**
	* Gives size in bytes of the memory mapped file.
	*/
	@property ulong length() const
	{
	debug (MMFILE) printf("MmFile.length()\n");
	return size;
	}
	
	alias opDollar = length;
	
private:
	string filename;
	void[] data;
	ulong  start;
	size_t window;
	ulong  size;
	void*  address;
	version (linux) File file;
	size_t length;

	version (Windows)
	{
		HANDLE hFile;
		HANDLE hFileMap;
		uint dwDesiredAccess;
	}
	else version (Posix)
	{
		int fd;
		int prot;
		int flags;
		int fmode;
		int oflag;
		int fmode;
	}
}
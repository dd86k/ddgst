import std.stdio, std.mmfile;
import std.compiler : version_major, version_minor;
import std.path : baseName;
import ddh.ddh;

extern (C) __gshared {
	debug private bool rt_cmdline_enabled = true;
	else  private bool rt_cmdline_enabled = false;

	private bool rt_envvars_enabled = false;

	// This starts with the GC disabled, with -vgc we can see that the GC
	// will be re-enabled to allocate MmFile into the heap, but that's
	// pretty much it
	private string[] rt_options = [ "gcopt=disable:1" ];
}

debug private enum BUILD_TYPE = "debug";
else  private enum BUILD_TYPE = "release";

private enum PROJECT_VERSION = "0.1.0";

private enum CHUNK_SIZE = 64 * 1024;

private enum InputStrategy
{
	/// std.file
	StdFile,
	/// std.mmfile
	StdMmFile,
	/// Use standard input
	Stdin,
}

private immutable string FMT_VERSION =
`ddh v`~PROJECT_VERSION~`-`~BUILD_TYPE~` (`~__TIMESTAMP__~`)
Compiler: `~__VENDOR__~" for v%u.%03u";

//        ddh {hash|checksum|encoding} [--options..] -- input
private immutable string TEXT_HELP =
`Usage: ddh page
       ddh {hash|checksum} file [options...]

Pages
help ......... Show this help screen and exit
version ...... Show application version screen and exit
ver .......... Only show version and exit
license ...... Show license screen and exit

Hashes
ripemd160 .... RIPEMD-160
sha1 ......... SHA-1-160
sha256 ....... SHA-2-256
sha512 ....... SHA-2-512

Checksums
crc32 ........ CRC-32
crc64iso ..... CRC-64-ISO
crc64ecma .... CRC-64-ECMA

Options
-mmfile ...... Input mode: Memory-map file (MmFile)
- ............ Input mode: Standard Input (stdin)`;

private immutable string TEXT_LICENSE =
`This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>`;

private int main(string[] args)
{
	const size_t argc = args.length;
	
	if (argc <= 1)
	{
		writeln(TEXT_HELP);
		return 0;
	}
	
	DDHAction action = void;
	
	switch (args[1])
	{
	//
	// Hashes
	//
	case "sha512":
		action = DDHAction.HashSHA512;
		break;
	case "sha256":
		action = DDHAction.HashSHA256;
		break;
	case "sha1":
		action = DDHAction.HashSHA1;
		break;
	case "ripemd160":
		action = DDHAction.HashRIPEMD160;
		break;
	case "md5":
		action = DDHAction.HashMD5;
		break;
	//
	// Checksums
	//
	case "crc64ecma":
		action = DDHAction.SumCRC64ECMA;
		break;
	case "crc64iso":
		action = DDHAction.SumCRC64ISO;
		break;
	case "crc32":
		action = DDHAction.SumCRC32;
		break;
	//
	// Actions
	//
	case "ver":
		writeln(PROJECT_VERSION);
		return 0;
	case "help", "--help":
		writeln(TEXT_HELP);
		return 0;
	case "version", "--version":
		writefln(FMT_VERSION, version_major, version_minor);
		return 0;
	case "license":
		writeln(TEXT_LICENSE);
		return 0;
	default:
		stderr.writefln("unknown action: %s", args[1]);
		return 1;
	}
	
	//TODO: -: argument for passing stdin/text input
	//TODO: -utf16/-utf32: Used to transform CLI utf-8 text into other encodings
	//      Reason: CLI is of type string, which is UTF-8 (even on Windows)
	//      So the translate would provide an aid for these encodings, even
	//      when raw, the data is processed as-is.
	//TODO: -P/--progress: Consider adding progress bar
	//TODO: -c/--check: Check against file
	InputStrategy strat;	// Defaults to File
//	size_t cli_fileslen;	/// File index/length
//	string[32] cli_files = void;	/// Files to process
	uint cli_seed;	/// Defaults to 0
	
	if (argc <= 2)
	{
		//stderr.writeln("main: missing file");
		//return 1;
		strat = InputStrategy.Stdin;
		goto L_DDH_INIT;
	}

	L_CLI: for (size_t argi = 3; argi < argc; ++argi)
	{
		const string arg = args[argi];
		if (arg[0] == '-')
		{
			switch (arg)
			{
			case "-mmfile":
				strat = InputStrategy.StdMmFile;
				continue;
			case "-":
				strat = InputStrategy.Stdin;
				++argi;
				break L_CLI;
			default:
				stderr.writefln("unknown option: %s", arg);
				return 1;
			}
		}
		/+else
		{
			cli_files[cli_fileslen++] = arg;
		}+/
	}

L_DDH_INIT:
	DDH_T ddh = void;
	if (ddh_init(ddh, action, cli_seed))
	{
		perror(__FUNCTION__);
		return 1;
	}
	
	//TODO: Find a way to read and process data concurrently
	//      Not to be confused with multi-threading, this would simply
	//      ensure that data is loaded in memory from disk before
	//      computation, e.g. load next group while hashing current.
	//      Or just set the chunk size according to the environment.
	
	with (InputStrategy)
	final switch (strat)
	{
	case StdFile:
		File f;	// Must never be void, see BUG
		ulong flen = void;
		try
		{
			// BUG: LDC2 has an issue with opAssign, crashing
			//      the whole thing
			f.open(args[2]);
			flen = f.size();
		}
		catch (Exception ex)
		{
			stderr.writefln("main: %s", ex.msg);
			return 1;
		}
		
		if (flen)
		foreach (ubyte[] chunk; f.byChunk(CHUNK_SIZE))
		{
			ddh_compute(ddh, chunk);
		}
		break;
	case StdMmFile:
		MmFile f = void;
		ulong flen = void;
		try
		{
			f = new MmFile(args[2]);
			flen = f.length;
		}
		catch (Exception ex)
		{
			stderr.writefln("main: %s", ex.msg);
			return 1;
		}
		
		//TODO: Consider using [] instead of memory chunks
		//      Perhaps with a -mmfull setting?
		//      Let's do a benchmark as a unittest first.
		if (flen)
		{
			ulong start;
			const ulong climit = flen - CHUNK_SIZE;
			for (; start < climit; start += CHUNK_SIZE)
				ddh_compute(ddh, cast(ubyte[])f[start..start + CHUNK_SIZE]);
			
			// Compute remaining
			ddh_compute(ddh, cast(ubyte[])f[start..flen]);
		}
		break;
	case Stdin:
		foreach (ubyte[] chunk; stdin.byChunk(CHUNK_SIZE))
		{
			ddh_compute(ddh, chunk);
		}
		break;
	}
	
	writeln(ddh_string(ddh));
	
	return 0;
}

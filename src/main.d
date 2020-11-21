import std.stdio, std.mmfile;
import std.compiler : version_major, version_minor;
import std.path : baseName, dirName;
import std.file : dirEntries, DirEntry, SpanMode;
import ddh.ddh;
static import log = logger;

private:

extern (C) __gshared {
	debug bool rt_cmdline_enabled = true;
	else  bool rt_cmdline_enabled = false;

	bool rt_envvars_enabled = false;

	// This starts with the GC disabled, with -vgc we can see that the GC
	// will be re-enabled to allocate MmFile into the heap, but that's
	// pretty much it
	string[] rt_options = [ "gcopt=disable:1" ];
}

debug enum BUILD_TYPE = "debug";
else  enum BUILD_TYPE = "release";

enum PROJECT_VERSION = "0.2.0";
enum PROJECT_NAME    = "ddh";

/// Amount of data to process at once.
/// Modes: File, MmFile, stdin
enum CHUNK_SIZE = 64 * 1024;

immutable string FMT_VERSION =
PROJECT_NAME~` v`~PROJECT_VERSION~`-`~BUILD_TYPE~` (`~__TIMESTAMP__~`)
Compiler: `~__VENDOR__~" for v%u.%03u";

immutable string TEXT_HELP =
`Usage: ddh page
       ddh {checksum|hash} [options...] [{file|-}...]

Pages
help ........... Show this help screen and exit
version ........ Show application version screen and exit
ver ............ Only show version and exit
license ........ Show license screen and exit

Options
-M, --mmfile ... Input mode: Memory-map file (std.mmfile)
-F, --file ..... Input mode: Regular file (std.stdio)
- .............. Input mode: Standard input (stdin)
-- ............. Stop processing options

Alias        Name
crc32        CRC-32
crc64iso     CRC-64-ISO
crc64ecma    CRC-64-ECMA
md5          MD5
ripemd160    RIPEMD-160
sha1         SHA-1-160
sha224       SHA-2-224
sha256       SHA-2-256
sha384       SHA-2-384
sha512       SHA-2-512`;
//                                                         80 column marker -> |

immutable string TEXT_LICENSE =
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

immutable string STDIN_BASENAME = "-";

int process_file(ref string path, ref DDH_T ddh)
{
	//TODO: Find a way to read and process data concurrently for File
	//      Not to be confused with multi-threading, this would simply
	//      ensure that data is loaded in memory from disk before
	//      computation, e.g. load next group while hashing current.
	//      Or just set the chunk size according to the environment.
	File f;	// Must never be void, see BUG
	ulong flen = void;
	try
	{
		// BUG: Using LDC2 crashes at runtime with opAssign
		f.open(path);
		flen = f.size();
	}
	catch (Exception ex)
	{
		log.error(ex.msg);
		return true;
	}

	if (flen)
	foreach (ubyte[] chunk; f.byChunk(CHUNK_SIZE))
		ddh_compute(ddh, chunk);
	
	return false;
}

int process_mmfile(ref string path, ref DDH_T ddh)
{
	MmFile f = void;
	ulong flen = void;
	try
	{
		f = new MmFile(path);
		flen = f.length;
	}
	catch (Exception ex)
	{
		log.error(ex.msg);
		return true;
	}
	
	if (flen)
	{
		ulong start;
		if (flen > CHUNK_SIZE)
		{
			const ulong climit = flen - CHUNK_SIZE;
			for (; start < climit; start += CHUNK_SIZE)
				ddh_compute(ddh, cast(ubyte[])f[start..start + CHUNK_SIZE]);
		}
		
		// Compute remaining
		ddh_compute(ddh, cast(ubyte[])f[start..flen]);
	}
	
	return false;
}

int process_stdin(ref DDH_T ddh)
{
	foreach (ubyte[] chunk; stdin.byChunk(CHUNK_SIZE))
	{
		ddh_compute(ddh, chunk);
	}
	return false;
}

int main(string[] args)
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
	case "sha384":
		action = DDHAction.HashSHA384;
		break;
	case "sha256":
		action = DDHAction.HashSHA256;
		break;
	case "sha224":
		action = DDHAction.HashSHA224;
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
		write(TEXT_HELP);
		return 0;
	case "version", "--version":
		writefln(FMT_VERSION, version_major, version_minor);
		return 0;
	case "license":
		writeln(TEXT_LICENSE);
		return 0;
	default:
		log.error(PROJECT_NAME~": unknown action '%s'", args[1]);
		return 1;
	}
	
	DDH_T ddh = void;
	if (ddh_init(ddh, action))
	{
		perror(__FUNCTION__);
		return 1;
	}
	
	if (argc <= 2)
	{
		process_stdin(ddh);
		writefln("%s  -", ddh_string(ddh));
		return 0;
	}
	
	//TODO: --utf16/--utf32: Used to transform CLI utf-8 text into other encodings
	//      Reason: CLI is of type string, which is UTF-8 (even on Windows)
	//      So the translate would provide an aid for these encodings, even
	//      when raw, the data is processed as-is.
	//TODO: -P/--progress: Consider adding progress bar
	//TODO: -c/--check: Check against file
	//TODO: -u/--upper: Upper case hash digests
	//TODO: -C/--continue: Continue to next file on error
	//TODO: --color: Errors with color
	//TODO: -p/--parallel: std.parallalism.parallel dirEntries
	
	int function(ref const string, ref DDH_T) pfunc = &process_file;
	int presult = void;	/// Process function result
	bool cli_skip;	/// Skip CLI options, default=false
//	uint cli_seed;	/// Defaults to 0
	
	for (size_t argi = 2; argi < argc; ++argi)
	{
		string arg = args[argi];
		
		if (cli_skip)
		{
			presult = pfunc(arg, ddh);
			if (presult) return presult;
			writefln("%s  %s", ddh_string(ddh), baseName(arg));
			ddh_reinit(ddh);
			continue;
		}
		
		if (arg[0] == '-')
		{
			if (arg.length == 1) // '-' only: stdin
			{
				process_stdin(ddh);
				writefln("%s  -", ddh_string(ddh));
				continue;
			}
			
			if (arg[1] == '-') // long opts
			{
				switch (arg)
				{
				case "--mmfile":
					pfunc = &process_mmfile;
					continue;
				case "--file":
					pfunc = &process_file;
					continue;
				case "--":
					cli_skip = true;
					continue;
				default:
					log.error(PROJECT_NAME~": unknown option '%s'", arg);
					return 1;
				}
			}
			
			foreach (char o; arg[1..$])
			switch (o)
			{
			case 'M':
				pfunc = &process_mmfile;
				continue;
			case 'F':
				pfunc = &process_file;
				continue;
			default:
				log.error(PROJECT_NAME~": unknown option '%c'", o);
				return 1;
			}
		}
		
		uint count;
		string dir  = dirName(arg);
		string name = baseName(arg); // Thankfully doesn't remove glob patterns
		foreach (DirEntry entry; dirEntries(dir, name, SpanMode.shallow))
		{
			++count;
			if (entry.isDir)
				continue;
			string path = entry.name;
			presult = pfunc(path, ddh);
			if (presult)
				return presult;
			writefln("%s  %s", ddh_string(ddh), baseName(path));
			ddh_reinit(ddh);
		}
		if (count == 0)
			log.error("'%s': No such file", name);
	}
	
	return 0;
}

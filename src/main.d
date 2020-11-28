import std.stdio, std.mmfile;
import std.compiler : version_major, version_minor;
import std.path : baseName, dirName;
import std.file : dirEntries, DirEntry, SpanMode;
import ddh.ddh;
static import log = logger;

private:

extern (C) __gshared {
	// The RT CLI is pretty useless
	bool rt_cmdline_enabled = false;

	// This starts with the GC disabled, with -vgc we can see that the GC
	// will be re-enabled to allocate MmFile into the heap, but that's
	// pretty much it
	string[] rt_options = [ "gcopt=disable:1 cleanup:none" ];
}

debug enum BUILD_TYPE = "debug";
else  enum BUILD_TYPE = "release";

enum PROJECT_VERSION = "0.4.0";
enum PROJECT_NAME    = "ddh";

enum CLIFlags {
	FileText = 0x8000_0000,
}

alias process_func_t = int function(ref const string path, ref DDH_T ddh);

immutable string FMT_VERSION =
PROJECT_NAME~` v`~PROJECT_VERSION~`-`~BUILD_TYPE~` (`~__TIMESTAMP__~`)
Compiler: `~__VENDOR__~" for v%u.%03u";

immutable string TEXT_HELP =
`Usage:
  ddh page
  ddh alias [-]
  ddh alias [options...] [{file|-}...]

Pages:
  list ............. List supported checksum and hash algorithms
  help ............. Show this help screen and exit
  version .......... Show application version screen and exit
  ver .............. Only show version and exit
  license .......... Show license screen and exit

Input mode options:
  -F, --file ....... Input mode: Regular file (std.stdio, default)
    -t, --text ....... Set text mode
    -b, --binary ..... Set binary mode (default)
  -M, --mmfile ..... Input mode: Memory-map file (std.mmfile)
  -a, --arg ........ Input mode: Command-line argument text (utf-8)
  -c, --check ...... Check hashes against a file
  - ................ Input mode: Standard input (stdin)

Embedded globber options:
  --shallow ........ Depth: Same directory (default)
  -s, --depth ...... Depth: Deepest directories first
  --breadth ........ Depth: Sub directories first
  --follow ......... Links: Follow symbolic links (default)
  --nofollow ....... Links: Do not follow symbolic links

Misc. options:
  -- ............... Stop processing options`;
//                                                         80 column marker -> |
/*
  -C, --chunk ...... Set chunk size (default=64k)
                     Modes: file, mmfile, stdin*/

immutable string TEXT_ALIASES =
`Aliases:
  crc32 .......... CRC-32
  crc64iso ....... CRC-64-ISO
  crc64ecma ...... CRC-64-ECMA
  md5 ............ MD5-128
  ripemd160 ...... RIPEMD-160
  sha1 ........... SHA-1-160
  sha224 ......... SHA-2-224
  sha256 ......... SHA-2-256
  sha384 ......... SHA-2-384
  sha512 ......... SHA-2-512
  sha3-224 ....... SHA-3-224
  sha3-256 ....... SHA-3-256
  sha3-384 ....... SHA-3-384
  sha3-512 ....... SHA-3-512
  shake128 ....... SHAKE-128
  shake256 ....... SHAKE-256`;

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
	File f;	// Must never be void, see BUG
	ulong flen = void;
	try
	{
		// BUG: Using LDC2 crashes at runtime with opAssign
		f.open(path, ddh.flags >= CLIFlags.FileText ? "r" : "rb");
		flen = f.size();
	}
	catch (Exception ex)
	{
		log.error("%s: %s", path, ex.msg);
		return true;
	}

	//TODO: Find a way to read and process data concurrently for File
	//      Not to be confused with multi-threading, this would simply
	//      ensure that data is loaded in memory from disk before
	//      computation, e.g. load next group while hashing current.
	//      Or just set the chunk size according to the environment.
	if (flen)
	foreach (ubyte[] chunk; f.byChunk(ddh.chunksize))
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
		log.error("%s: %s", path, ex.msg);
		return true;
	}
	
	if (flen)
	{
		ulong start;
		if (flen > ddh.chunksize)
		{
			const ulong climit = flen - ddh.chunksize;
			for (; start < climit; start += ddh.chunksize)
				ddh_compute(ddh, cast(ubyte[])f[start..start + ddh.chunksize]);
		}
		
		// Compute remaining
		ddh_compute(ddh, cast(ubyte[])f[start..flen]);
	}
	
	return false;
}

void process_text(ref string text, ref DDH_T ddh)
{
	ddh_compute(ddh, cast(ubyte[])text);
	writefln("%s  -", ddh_string(ddh));
}

int process_stdin(ref DDH_T ddh)
{
	foreach (ubyte[] chunk; stdin.byChunk(ddh.chunksize))
	{
		ddh_compute(ddh, chunk);
	}
	writefln("%s  -", ddh_string(ddh));
	return false;
}

int process_check(ref const string path, ref DDH_T ddh, process_func_t pfunc)
{
	import std.conv : text;
	
	File cf;
	try
	{
		cf.open(path);
	}
	catch (Exception ex)
	{
		log.error(ex.msg);
		return 1;
	}
	
	// Number of characters the hash string is
	size_t hashsize = ddh_digest_size(ddh) << 1;
	size_t minsize = hashsize + 3;
	
	uint linecnt;
	uint mismatches;
	uint notread;
	foreach (ref char[] line; cf.byLine)
	{
		++linecnt;
		
		if (line.length < minsize)
		{
			log.error("line %u invalid", linecnt);
			++notread;
			continue;
		}
		
		// Since it includes the newline
		string file = line[minsize - 1..$ - 1].text;
		
		if (pfunc(file, ddh))
		{
			++notread;
			continue;
		}
		
		if (line[0..hashsize] != ddh_string(ddh))
		{
			++mismatches;
			writeln(file, ": FAILED");
			continue;
		}
		
		writeln(file, ": OK");
	}
	if (mismatches || notread)
		log.warn("%u mismatched files, %u files not read", mismatches, notread);
	
	return 0;
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
	case "sha3-512":
		action = DDHAction.HashSHA3_512;
		break;
	case "sha3-384":
		action = DDHAction.HashSHA3_384;
		break;
	case "sha3-256":
		action = DDHAction.HashSHA3_256;
		break;
	case "sha3-224":
		action = DDHAction.HashSHA3_224;
		break;
	case "shake256":
		action = DDHAction.HashSHAKE256;
		break;
	case "shake128":
		action = DDHAction.HashSHAKE128;
		break;
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
	// Pages
	//
	case "list":
		writeln(TEXT_ALIASES);
		return 0;
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
		log.error("unknown action '%s'", args[1]);
		return 1;
	}
	
	DDH_T ddh = void;
	if (ddh_init(ddh, action))
	{
		log.error("could not initiate hash");
		return 1;
	}
	
	if (argc <= 2)
	{
		process_stdin(ddh);
		return 0;
	}
	
	//TODO: -P/--progress: Consider adding progress bar
	//TODO: -u/--upper: Upper case hash digests
	//TODO: --nocolor/--color: Errors with color
	//TODO: -j/--jobs: std.parallalism.parallel dirEntries
	
	process_func_t pfunc = &process_file;
	int presult = void;	/// Process function result
	SpanMode cli_spanmode = SpanMode.shallow;
	bool cli_follow = true;
	bool cli_skip;	/// Skip CLI options, default=false
	
	for (size_t argi = 2; argi < argc; ++argi)
	{
		string arg = args[argi];
		
		if (cli_skip)
		{
			presult = pfunc(arg, ddh);
			if (presult) return presult;
			writefln("%s  %s", ddh_string(ddh), arg);
			ddh_reinit(ddh);
			continue;
		}
		
		if (arg[0] == '-')
		{
			if (arg.length == 1) // '-' only: stdin
			{
				process_stdin(ddh);
				continue;
			}
			
			// Long opts
			if (arg[1] == '-')
			switch (arg)
			{
			// Input mode
			case "--mmfile":
				pfunc = &process_mmfile;
				continue;
			case "--file":
				pfunc = &process_file;
				continue;
			case "--check":
				++argi;
				if (argi >= argc)
				{
					log.error("missing argument");
					return 1;
				}
				process_check(args[argi++], ddh, pfunc);
				continue;
			case "--arg":
				++argi;
				if (argi >= argc)
				{
					log.error("missing argument");
					return 1;
				}
				process_text(args[argi++], ddh);
				continue;
			// Read mode
			case "--text":
				ddh.flags |= CLIFlags.FileText;
				continue;
			case "--binary":
				ddh.flags &= ~CLIFlags.FileText;
				continue;
			// SpanMode
			case "--depth":
				cli_spanmode = SpanMode.depth;
				continue;
			case "--breadth":
				cli_spanmode = SpanMode.breadth;
				continue;
			case "--shallow":
				cli_spanmode = SpanMode.shallow;
				continue;
			// Follow symbolic links
			case "--nofollow":
				cli_follow = false;
				continue;
			case "--follow":
				cli_follow = true;
				continue;
			// Misc.
			/*case "--chunk":
				continue;*/
			case "--":
				cli_skip = true;
				continue;
			default:
				log.error(PROJECT_NAME~": unknown option '%s'", arg);
				return 1;
			}
			
			// Short opts
			foreach (char o; arg[1..$])
			switch (o)
			{
			case 'M': // mmfile input
				pfunc = &process_mmfile;
				continue;
			case 'F': // file input
				pfunc = &process_file;
				continue;
			case 't': // text file mode
				ddh.flags |= CLIFlags.FileText;
				continue;
			case 'b': // binary file mode
				ddh.flags &= ~CLIFlags.FileText;
				continue;
			case 's': // spanmode: depth
				cli_spanmode = SpanMode.depth;
				continue;
			/*case 'C':
				continue;*/
			case 'c': // check
				++argi;
				if (argi >= argc)
				{
					log.error("missing argument");
					return 1;
				}
				process_check(args[argi++], ddh, pfunc);
				continue;
			case 'a': // arg
				++argi;
				if (argi >= argc)
				{
					log.error("missing argument");
					return 1;
				}
				process_text(args[argi++], ddh);
				continue;
			default:
				log.error("unknown option '%c'", o);
				return 1;
			}
			
			continue;
		}
		
		uint count;
		string dir  = dirName(arg);
		string name = baseName(arg); // Thankfully doesn't remove glob patterns
		foreach (DirEntry entry; dirEntries(dir, name, cli_spanmode, cli_follow))
		{
			++count;
			if (entry.isDir)
				continue;
			string path = entry.name;
			presult = pfunc(path, ddh);
			if (presult)
				return presult;
			writefln("%s  %s", ddh_string(ddh), path[2..$]);
			ddh_reinit(ddh);
		}
		if (count == 0)
			log.error("'%s': No such file", name);
	}
	
	return 0;
}

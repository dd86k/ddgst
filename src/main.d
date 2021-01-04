import std.conv : text;
import std.compiler : version_major, version_minor;
import std.file : dirEntries, DirEntry, SpanMode;
import std.format : format;
import std.path : baseName, dirName;
import std.stdio, std.mmfile;
import ddh.ddh;
static import log = logger;

private:

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = [ "cleanup:none" ];

// The DRT CLI is pretty useless
extern (C) __gshared bool rt_cmdline_enabled = false;

debug enum BUILD_TYPE = "debug";
else  enum BUILD_TYPE = "release";

enum PROJECT_VERSION = "0.4.2";
enum PROJECT_NAME    = "ddh";

enum DEFAULT_CHUNK_SIZE = 64 * 1024;

struct ArgInput
{
	DDH_T ddh;
	string path;	/// or text
	uint chunksize;	/// file, mmfile: chunk read/process size
	bool filetext;	/// file: read as text
}

alias process_func_t = int function(ref ArgInput);

immutable string TEXT_VERSION =
PROJECT_NAME~` v`~PROJECT_VERSION~`-`~BUILD_TYPE~` (`~__TIMESTAMP__~`)
Compiler: `~__VENDOR__~" FE v"~format("%u.%03u", version_major, version_minor);

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

int process_file(ref ArgInput ai)
{
	File f;	// Must never be void, see BUG
	ulong flen = void;
	try
	{
		// BUG: Using LDC2 crashes at runtime with opAssign
		f.open(ai.path, ai.filetext ? "r" : "rb");
		flen = f.size();
	}
	catch (Exception ex)
	{
		log.error("'%s': %s", ai.path, ex.msg);
		return true;
	}

	if (flen)
	{
		foreach (ubyte[] chunk; f.byChunk(ai.chunksize))
			ddh_compute(ai.ddh, chunk);
	}
	
	f.close();
	
	return false;
}

int process_mmfile(ref ArgInput ai)
{
	MmFile f = void;
	ulong flen = void;
	try
	{
		f = new MmFile(ai.path);
		flen = f.length;
	}
	catch (Exception ex)
	{
		log.error("'%s': %s", ai.path, ex.msg);
		return true;
	}
	
	if (flen)
	{
		ulong start;
		
		if (flen > ai.chunksize)
		{
			const ulong climit = flen - ai.chunksize;
			for (; start < climit; start += ai.chunksize)
				ddh_compute(ai.ddh, cast(ubyte[])f[start..start + ai.chunksize]);
		}
		
		// Compute remaining
		ddh_compute(ai.ddh, cast(ubyte[])f[start..flen]);
	}
	
	return false;
}

void process_textarg(string str, ref ArgInput ai)
{
	ddh_compute(ai.ddh, cast(ubyte[])str);
	print_result!"%s  \"%s\""(ddh_string(ai.ddh), str);
}

int process_stdin(ref ArgInput ai)
{
	foreach (ubyte[] chunk; stdin.byChunk(ai.chunksize))
		ddh_compute(ai.ddh, chunk);
	print_result(ddh_string(ai.ddh), STDIN_BASENAME);
	return false;
}

int process_check(string path, ref ArgInput ai, process_func_t pfunc)
{
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
	
	/// Number of characters the hash string
	size_t hashsize = ddh_digest_size(ai.ddh) << 1;
	/// Minimum line length
	size_t minsize = hashsize + 2;
	
	uint res_linecount, res_mismatch, res_err;
	foreach (char[] line; cf.byLine)
	{
		++res_linecount;
		
		// Skip '#' comments
		if (line[0] == '#')
			continue;
		
		if (line.length <= minsize)
		{
			log.error("Line %u invalid", res_linecount);
			++res_err;
			continue;
		}
		
		// FileArg.path is modified for the file function
		// `..$-1`: Since `.byLine` includes the newline
		ai.path = line[minsize..$-1].text;
		
		// Process file
		if (pfunc(ai))
		{
			++res_err;
			continue;
		}
		
		// Compare hash/checksum
		if (line[0..hashsize] != ddh_string(ai.ddh))
		{
			++res_mismatch;
			writeln(ai.path, ": FAILED");
			continue;
		}
		
		writeln(ai.path, ": OK");
	}
	if (res_mismatch || res_err)
		log.warn("%u mismatched file(s), %u file(s) not read", res_mismatch, res_err);
	
	return 0;
}

void print_result(string fmt = "%s  %s")(char[] hash, in char[] file)
{
	writefln(fmt, hash, file);
}

int main(string[] args)
{
	const size_t argc = args.length;
	
	if (argc <= 1)
	{
		writeln(TEXT_HELP);
		return 0;
	}
	
	string arg = args[1];
	DDHAction action = cast(DDHAction)-1;
	foreach (meta; meta_info)
	{
		if (meta.basename == arg)
		{
			action = meta.action;
			break;
		}
	}
	
	// Pages
	if (action == -1)
	switch (args[1])
	{
	case "list":
		writeln("Aliases");
		foreach (meta; meta_info)
			writefln("%-12s%s",
				meta.basename, meta.name);
		return 0;
	case "ver":
		writeln(PROJECT_VERSION);
		return 0;
	case "help", "--help":
		write(TEXT_HELP);
		return 0;
	case "version", "--version":
		writeln(TEXT_VERSION);
		return 0;
	case "license":
		writeln(TEXT_LICENSE);
		return 0;
	default:
		log.error("Unknown action '%s'", args[1]);
		return 1;
	}
	
	ArgInput ai = void;
	// NOTE: LDC2 optimization bug
	//       ArgInput fields must be initiated here
	ai.chunksize = DEFAULT_CHUNK_SIZE;
	ai.filetext = false;
	
	if (ddh_init(ai.ddh, action))
	{
		log.error("Could not initiate hash");
		return 1;
	}
	
	if (argc <= 2)
	{
		process_stdin(ai);
		return 0;
	}
	
	// CLI arguments
	process_func_t pfunc = &process_file; /// Process function
	int presult = void;	/// Process function result
	SpanMode cli_spanmode; /// dirEntries: span mode, default=shallow
	bool cli_follow = true; /// dirEntries: follow symlinks
	bool cli_skip;	/// Skip CLI options, default=false
	
	// Main CLI loop
	// getopt isn't used (for now?) for "on-the-go" specific behaviour
	for (size_t argi = 2; argi < argc; ++argi)
	{
		arg = args[argi];
		
		if (cli_skip)
		{
			ai.path = arg;
			presult = pfunc(ai);
			if (presult) return presult;
			print_result(ddh_string(ai.ddh), arg);
			ddh_reset(ai.ddh);
			continue;
		}
		
		if (arg[0] == '-')
		{
			if (arg.length == 1) // '-' only: stdin
			{
				process_stdin(ai);
				continue;
			}
			
			//
			// Long opts
			//
			if (arg[1] == '-')
			switch (arg)
			{
			// Input modes
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
					log.error("Missing argument");
					return 1;
				}
				process_check(args[argi++], ai, pfunc);
				continue;
			case "--arg":
				++argi;
				if (argi >= argc)
				{
					log.error("Missing argument");
					return 1;
				}
				process_textarg(args[argi++], ai);
				continue;
			// Read modes for File
			case "--text":
				ai.filetext = true;
				continue;
			case "--binary":
				ai.filetext = false;
				continue;
			// Span modes
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
				log.error("Unknown option '%s'", arg);
				return 1;
			}
			
			//
			// Short opts
			//
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
				ai.filetext = true;
				continue;
			case 'b': // binary file mode
				ai.filetext = false;
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
				process_check(args[argi++], ai, pfunc);
				continue;
			case 'a': // arg
				++argi;
				if (argi >= argc)
				{
					log.error("missing argument");
					return 1;
				}
				process_textarg(args[argi++], ai);
				continue;
			default:
				log.error("Unknown option '%c'", o);
				return 1;
			}
			
			continue;
		}
		
		uint count;
		string dir  = dirName(arg);  // "." if anything
		string name = baseName(arg); // Glob patterns are kept
		const bool samedir = dir == ".";
		L_ENTRY: foreach (DirEntry entry; dirEntries(dir, name, cli_spanmode, cli_follow))
		{
			ai.path = samedir ? entry.name[2..$] : entry.name;
			++count;
			if (entry.isDir) {
				log.error("'%s': Is a directory", ai.path);
				continue L_ENTRY;
			}
			if (pfunc(ai)) {
				log.error("'%s': Couldn't open file", ai.path);
				continue L_ENTRY;
			}
			print_result(ddh_string(ai.ddh), ai.path);
			ddh_reset(ai.ddh);
		}
		if (count == 0)
			log.error("'%s': No such file", name);
	}
	
	return 0;
}

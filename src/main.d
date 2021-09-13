/**
 * Command-line interface.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module main;

import std.conv : text;
import std.compiler : version_major, version_minor;
import std.file : dirEntries, DirEntry, SpanMode;
import std.format : format, formattedRead;
import std.path : baseName, dirName;
import std.stdio, std.mmfile;
import ddh.ddh, hasher;

private:

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = [ "cleanup:none" ];

// The DRT CLI is pretty useless
extern (C) __gshared bool rt_cmdline_enabled = false;

debug enum BUILD_TYPE = "-debug";
else  enum BUILD_TYPE = "";

enum PROJECT_VERSION = "1.0.0";
enum PROJECT_NAME    = "ddh";

immutable string TEXT_VERSION =
PROJECT_NAME~` v`~PROJECT_VERSION~BUILD_TYPE~` (`~__TIMESTAMP__~`)
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
  -c, --check ...... Check hashes list in this file
  -C, --chunk ...... Set chunk size (default=64K)
                     Modes affected: file, mmfile, stdin
  - ................ Input mode: Standard input (stdin)

Embedded globber options:
  --shallow ........ Depth: Same directory (default)
  -s, --depth ...... Depth: Deepest directories first
  --breadth ........ Depth: Sub directories first
  --follow ......... Links: Follow symbolic links (default)
  --nofollow ....... Links: Do not follow symbolic links

Misc. options:
  -- ............... Stop processing options`;

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

deprecated
immutable string F_EX = "%s: %s"; /// Used in printing exception messages

int printError(string func = __FUNCTION__, A...)(string fmt, A args) {
	stderr.write(func, ": ");
	stderr.writefln(fmt, args);
	return 1;
}
int printError(ref Exception ex, string func = __FUNCTION__) {
	debug stderr.writefln("%s: %s", func, ex);
	else  stderr.writefln("%s: %s", func, ex.msg);
	return 1;
}

// String to binary size
int strtobin(ulong *size, string input) {
	enum {
		K = 1024,
		M = K * 1024,
		G = M * 1024,
		T = G * 1024,
	}
	
	float f; char c;
	try
	{
		if (input.formattedRead!"%f%c"(f, c) != 2)
			return 1;
	}
	catch (Exception)
	{
		return 2;
	}
	
	if (f <= 0.0f) return 3;
	
	ulong u = cast(ulong)f;
	switch (c) {
	case 'T', 't': u *= T; break;
	case 'G', 'g': u *= G; break;
	case 'M', 'm': u *= M; break;
	case 'K', 'k': u *= K; break;
	case 'B', 'b': break;
	default: return 4;
	}
	
	// limit
	version (D_LP64) {
		if (u > (4L * G))
			return 5;
	} else {
		if (u > (2 * G))
			return 5;
	}
	
	*size = u;
	return 0;
}
/// 
unittest
{
	ulong s = void;
	strtobin(&s, "1K");
	assert(s == 1024);
	strtobin(&s, "1.1K");
	assert(s == 1024 + 102); // 102.4
}

void printResult(string fmt = "%s  %s")(char[] hash, in char[] file)
{
	writefln(fmt, hash, file);
}

int processText(ref Hasher p, string text)
{
	int e = p.processText(text);
	if (e == 0)
		printResult!`%s  "%s"`(p.hash, text);
	return e;
}
	
int processList(ref Hasher p, string path)
{
	import std.file : readText;
	import std.utf : UTFException;
	import std.algorithm.iteration : splitter;
	
	/// Number of characters the hash string.
	size_t hashsize = ddh_digest_size(p.ddh) << 1;
	/// Minimum line length (hash + 1 spaces).
	// Example: abcd1234  file.txt
	size_t minsize = hashsize + 1;
	
	union text_t
	{
		string utf8;
		wstring utf16;
		dstring utf32;
	}
	text_t text = void;
	
	try
	{
		text.utf8 = readText(path);
	}
	catch (Exception ex)
	{
		return printError(ex);
	}
	
	size_t len = text.utf8.length;
	
	if (len == 0)
		return printError("File '%s' is empty", path);
	
	if (len < minsize)
		return printError("File '%s' too small", path);
	
	// Newline detection
	enum MAX = 1024;
	string newline = "\n"; // default
	size_t l = text.utf8.length - 1; // @suppress(dscanner.suspicious.length_subtraction)
	loop: for (size_t i; i < l && i < MAX; ++i)
	{
		char c = text.utf8[i];
		
		switch (c)
		{
		case '\n':
			newline = "\n";
			break loop;
		case '\r':
			newline = text.utf8[i + 1] == '\n' ? "\r\n" : "\r";
			break loop;
		default: continue loop;
		}
	}
	
	// Treat every hash line
	uint r_currline, r_mismatch, r_errors;
	foreach (string line; text.utf8.splitter(newline))
	{
		++r_currline;
		
		// Skip:
		// - Empty lines
		// - Comments starting with '#'
		if (line.length == 0 || line[0] == '#')
			continue;
		
		// Line needs to at least be hash length + 2 spaces + 1 character
		if (line.length <= minsize)
		{
			printError("Line %u invalid", r_currline);
			++r_errors;
			continue;
		}
		
		import std.string : stripLeft;
		
		// FileArg.path is modified for the file function.
		// There may be one or more spaces to its left.
		string filepath = line[minsize..$].stripLeft; /// File path
		
		// Process file
		int e = p.process(filepath);
		if (e)
		{
			printError("Failed to process '%s': %s", filepath, p.lastException.msg);
			++r_errors;
			continue;
		}
		
		// Compare hash/checksum
		if (line[0..hashsize] != p.hash)
		{
			printError("%s: FAILED", filepath);
			++r_mismatch;
			continue;
		}
		
		writeln(filepath, ": OK");
	}
	
	if (r_mismatch || r_errors)
		printError("%u file(s) mismatch, %u file(s) not read", r_mismatch, r_errors);
	
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
	
	string action = args[1];
	DDHType type = cast(DDHType)-1;
	
	// Aliases for hashes and checksums
	foreach (meta; meta_info)
	{
		if (meta.basename == action)
		{
			type = meta.type;
			break;
		}
	}
	
	// Pages
	if (type == -1)
	{
		switch (action)
		{
		case "list":
			writeln("Alias       Name");
			foreach (meta; meta_info)
				writefln("%-12s%s", meta.basename, meta.name);
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
			return printError("Unknown action '%s'", action);
		}
	}
	
	Hasher config = Hasher(type);
	
	int e = void;
	if (argc <= 2)
	{
		if ((e = config.processStdin) != 0)
			printError(config.lastException);
		else
			printResult(config.hash, "-");
		return e;
	}
	
	// CLI arguments
	SpanMode cli_spanmode;	/// dirEntries: span mode, default=shallow
	bool cli_follow = true;	/// dirEntries: follow symlinks
	bool cli_skip;	/// Skip CLI options, default=false
	
	// Main CLI loop
	// getopt isn't used (for now?) since:
	// - we handle '-' for stdin mode
	for (size_t argi = 2; argi < argc; ++argi)
	{
		string arg = args[argi];
		
		if (cli_skip)
		{
			e = config.process(arg);
			if ((e = config.process(arg)) != 0)
			{
				printError(config.lastException.msg);
				return e;
			}
			printResult(config.hash, arg);
			continue;
		}
		
		// It's an argument
		if (arg[0] == '-')
		{
			if (arg.length == 1) // '-' only: stdin
			{
				if ((e = config.processStdin) != 0)
				{
					printError(config.lastException.msg);
					return e;
				}
				printResult(config.hash, arg);
				continue;
			}
			
			// Long opts
			if (arg[1] == '-')
			{
				switch (arg)
				{
				// Input modes
				case "--mmfile":
					config.setModeMmFile;
					continue;
				case "--file":
					config.setModeFile;
					continue;
				case "--check":
					if (++argi >= argc)
					{
						printError("Missing argument");
						return 1;
					}
					processList(config, args[argi++]);
					continue;
				case "--arg":
					if (++argi >= argc)
					{
						printError("Missing argument");
						return 1;
					}
					processText(config, args[argi++]);
					continue;
				// Read modes for File
				case "--text":
					config.fileText = true;
					continue;
				case "--binary":
					config.fileText = false;
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
				case "--chunk":
					if (++argi >= argc)
					{
						printError("Missing argument");
						return 1;
					}
					string s = args[argi++];
					if (strtobin(&config.inputSize, s))
					{
						printError("Invalid binary size: %s", s);
						return 1;
					}
					continue;
				case "--":
					cli_skip = true;
					continue;
				default:
					printError("Unknown option '%s'", arg);
					return 1;
				}
			}
			
			// Short opts
			foreach (char o; arg[1..$])
			{
				switch (o)
				{
				case 'M': // mmfile input
					config.setModeMmFile;
					continue;
				case 'F': // file input
					config.setModeFile;
					continue;
				case 't': // text file mode
					config.fileText = true;
					continue;
				case 'b': // binary file mode
					config.fileText = false;
					continue;
				case 's': // spanmode: depth
					cli_spanmode = SpanMode.depth;
					continue;
				case 'C':
					if (++argi >= argc)
					{
						printError("Missing argument");
						return 1;
					}
					string s = args[argi++];
					if (strtobin(&config.inputSize, s))
					{
						printError("Invalid binary size: %s", s);
						return 1;
					}
					continue;
				case 'c': // check
					if (++argi >= argc)
					{
						printError("missing argument");
						return 2;
					}
					processList(config, args[argi++]);
					continue;
				case 'a': // arg
					if (++argi >= argc)
					{
						printError("missing argument");
						return 2;
					}
					processText(config, args[argi++]);
					continue;
				default:
					printError("Unknown option '%c'", o);
					return 1;
				}
			}
			
			continue;
		}
		
		uint count;
		string dir  = dirName(arg);  // "." if anything
		string name = baseName(arg); // Glob patterns are kept
		const bool same = dir == "."; // same directory name from dirName
		foreach (DirEntry entry; dirEntries(dir, name, cli_spanmode, cli_follow))
		{
			// Because entry will have "./" prefixed to it
			string path = same ? entry.name[2..$] : entry.name;
			++count;
			if (entry.isDir)
			{
				printError("'%s': Is a directory", path);
				continue;
			}
			if (config.process(path))
			{
				printError("'%s': %s", path, config.lastException.msg);
				continue;
			}
			printResult(config.hash, path);
		}
		if (count == 0)
			printError("'%s': No such file", name);
	}
	
	return 0;
}

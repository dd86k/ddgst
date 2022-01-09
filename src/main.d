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
import std.getopt;
import std.path : baseName, dirName;
import std.stdio;
import ddh;

private:

enum PROJECT_VERSION = "1.3.0";
enum PROJECT_NAME    = "ddh";
enum DEFAULT_CHUNK_SIZE = 64 * 1024; // Seemed the best in benchmarks at least
enum EntryMethod { file, text, list }
enum TagType { gnu, bsd, sri }

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = [ "cleanup:none" ];

// Disables the Druntime GC command-line interface
extern (C) __gshared bool rt_cmdline_enabled = false;

debug enum BUILD_TYPE = "-debug";
else  enum BUILD_TYPE = "";

immutable string PAGE_VERSION =
PROJECT_NAME~` `~PROJECT_VERSION~BUILD_TYPE~` (built: `~__TIMESTAMP__~`)
Using sha3-d 1.2.1, blake2-d 0.2.0
No Copyrights
License: Unlicense
Homepage: <https://github.com/dd86k/ddh>
Compiler: `~__VENDOR__~" v"~format("%u.%03u", version_major, version_minor);

immutable string PAGE_HELP =
`Usage: ddh command [options...] [files...] [-]

Commands
list      List all supported hashes and checksums.
help      This help page and exit.
ver       Only show version number and exit.
version   Show version page and exit.

Options
--                Stop processing options.
-                 Input mode: Standard input (stdin).`;

immutable string PAGE_LICENSE =
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

For more information, please refer to <http://unlicense.org/>.`;

immutable string PAGE_COFE = q"SECRET

      ) ) )
     ( ( (
    .......
   _|     |
  / |     |
  \_|     |
    `-----'
SECRET";

immutable string STDIN_NAME = "-";

struct Settings
{
	Ddh hasher;
	ubyte[] rawHash;
	string listPath;
	size_t bufferSize = DEFAULT_CHUNK_SIZE;
	SpanMode spanMode;
	bool follow = true;
	bool textMode;
	TagType type;
	EntryMethod method;
	
	int function(ref Settings, string) hash = &hashFile;
	
	int select(HashType type)
	{
		hasher.initiate(type);
		return 0;
	}
	
	void setEntryMode(string opt)
	{
		final switch (opt)
		{
		case "F|file":   hash = &hashFile; return;
		case "M|mmfile": hash = &hashMmfile; return;
		case "a|arg":	 method = EntryMethod.text; return;
		case "c|check":	 method = EntryMethod.list; return;
		}
	}
	
	void setFileModeText()
	{
		textMode = true;
	}
	
	void setFileModeBinary()
	{
		textMode = false;
	}
	
	void setBufferSize(string, string val)
	{
		ulong v = void;
		if (strtobin(&v, val))
			throw new GetOptException("Couldn't unformat buffer size");
		version (D_LP64) {}
		else {
			if (v >= uint.max)
				throw new GetOptException("Buffer size overflows");
		}
		bufferSize = cast(size_t)v;
	}
	
	void setSpanMode(string opt)
	{
		final switch (opt)
		{
		case "s|depth": spanMode = SpanMode.depth; return;
		case "shallow": spanMode = SpanMode.shallow; return;
		case "breath":  spanMode = SpanMode.breadth; return;
		}
	}
	
	void setFollow()
	{
		follow = true;
	}
	
	void setNofollow()
	{
		follow = false;
	}
}

version (Trace)
void trace(string func = __FUNCTION__, A...)(string fmt, A args)
{
	write("TRACE:", func, ": ");
	writefln(fmt, args);
}

int printError(string func = __FUNCTION__, A...)(int code, string fmt, A args)
{
	stderr.writef("error: (code %d) ", code);
	debug stderr.write("[", func, "] ");
	stderr.writefln(fmt, args);
	return code;
}
int printError(int code, Exception ex)
{
	stderr.writef("error: (code %d) ", code);
	debug stderr.writeln(ex);
	else  stderr.writeln(ex.msg);
	return code;
}
void printResult(string fmt = "%s")(ref Settings settings, in char[] file)
{
	enum fmtgnu = fmt ~ "  %s";
	enum fmtbsd = "%s(" ~ fmt ~ ")= %s";
	final switch (settings.type) with (TagType)
	{
	case gnu:
		writefln(fmtgnu, settings.hasher.toHex, file);
		break;
	case bsd:
		writefln(fmtbsd, settings.hasher.tagName(), file, settings.hasher.toHex);
		break;
	case sri:
		writeln(settings.hasher.aliasName(), '-', settings.hasher.toBase64);
		break;
	}
}

// String to binary size
int strtobin(ulong *size, string input) {
	enum {
		K = 1024,
		M = K * 1024,
		G = M * 1024,
		T = G * 1024,
	}
	
	float f = void;
	char c = void;
	try
	{
		if (input.formattedRead!"%f%c"(f, c) != 2)
			return 1;
	}
	catch (Exception ex)
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
	assert(strtobin(&s, "1K") == 0);
	assert(s == 1024);
	assert(strtobin(&s, "1.1K") == 0);
	assert(s == 1024 + 102); // 102.4
}

int hashFile(ref Settings settings, string path)
{
	version (Trace) trace("path=%s", path);
	
	try
	{
		File f;	// Must never be void
		// BUG: Using opAssign with LDC2 crashes at runtime
		f.open(path, settings.textMode ? "r" : "rb");
		
		if (f.size())
			hashFile(settings, f);
		
		f.close();
		return 0;
	}
	catch (Exception ex)
	{
		return printError(6, ex);
	}
}
int hashFile(ref Settings settings, ref File file)
{
	try
	{
		foreach (ubyte[] chunk; file.byChunk(settings.bufferSize))
			settings.hasher.put(chunk);
		
		settings.rawHash = settings.hasher.finish();
		settings.hasher.reset();
		return 0;
	}
	catch (Exception ex)
	{
		return printError(7, ex);
	}
}
int hashMmfile(ref Settings settings, string path)
{
	import std.typecons : scoped;
	import std.mmfile : MmFile;
	
	version (Trace) trace("path=%s", path);
	
	try
	{
		auto mmfile = scoped!MmFile(path);
		ulong flen = mmfile.length;
		
		if (flen)
		{
			ulong start;
			
			if (flen > settings.bufferSize)
			{
				const ulong climit = flen - settings.bufferSize;
				for (; start < climit; start += settings.bufferSize)
					settings.hasher.put(
						cast(ubyte[])mmfile[start..start + settings.bufferSize]);
			}
			
			// Compute remaining
			settings.hasher.put(cast(ubyte[])mmfile[start..flen]);
		}
		
		settings.rawHash = settings.hasher.finish();
		settings.hasher.reset();
		return 0;
	}
	catch (Exception ex)
	{
		return printError(8, ex);
	}
}
int hashStdin(ref Settings settings, string)
{
	version (Trace) trace("stdin");
	return hashFile(settings, stdin);
}
int hashText(ref Settings settings, string text)
{
	version (Trace) trace("text='%s'", text);
	
	try
	{
		settings.hasher.put(cast(ubyte[])text);
		settings.rawHash = settings.hasher.finish();
		settings.hasher.reset();
		return 0;
	}
	catch (Exception ex)
	{
		return printError(9, ex);
	}
}

int entryFile(ref Settings settings, string path)
{
	version (Trace) trace("path=%s", path);
	
	uint count;
	string dir  = dirName(path);  // "." if anything
	string name = baseName(path); // Glob patterns are kept
	const bool same = dir == "."; // same directory name from dirName
	foreach (DirEntry entry; dirEntries(dir, name, settings.spanMode, settings.follow))
	{
		// Because entry will have "./" prefixed to it
		string file = same ? entry.name[2..$] : entry.name;
		++count;
		if (entry.isDir)
		{
			printError(5, "'%s': Is a directory", file);
			continue;
		}
		if (settings.hash(settings, file))
		{
			continue;
		}
		printResult(settings, file);
	}
	if (count == 0)
		return printError(6, "'%s': No such file", name);
	return 0;
}
int entryStdin(ref Settings settings)
{
	version (Trace) trace("stdin");
	int e = hashStdin(settings, STDIN_NAME);
	if (e == 0)
		printResult(settings, STDIN_NAME);
	return e;
}
int entryText(ref Settings settings, string text)
{
	version (Trace) trace("text='%s'", text);
	int e = hashText(settings, text);
	if (e == 0)
		printResult!`"%s"`(settings, text);
	return e;
}

int entryList(ref Settings settings, string listPath)
{
	import std.file : readText;
	import std.string : lineSplitter;
	
	version (Trace) trace("list=%s", listPath);
	
	/// Number of characters the hash string.
	size_t hashSize = settings.hasher.length() << 1;
	/// Minimum line length (hash + 1 spaces).
	// Example: abcd1234  file.txt
	uint currentLine, statMismatch, statErrors;
	
	try
	{
		string text = readText(listPath);
	
		if (text.length == 0)
			return printError(10, "File '%s' is empty", listPath);
		
		string file = void, result = void, hash = void, lastHash;
		foreach (string line; lineSplitter(text)) // doesn't allocate
		{
			++currentLine;
			
			if (line.length == 0) continue; // empty
			if (line[0] == '#') continue; // comment
			
			final switch (settings.type) with (TagType)
			{
			case gnu:
				// Tested to work with one or many spaces
				if (formattedRead(line, "%s %s", result, file) != 2)
				{
					++statErrors;
					printError(11, "Formatting error at line %u", currentLine);
					continue;
				}
				break;
			case bsd:
				// Tested to work with and without spaces
				if (formattedRead(line, "%s(%s) = %s", hash, file, result) != 3)
				{
					++statErrors;
					printError(12, "Formatting error at line %u", currentLine);
					continue;
				}
				
				if (hash == lastHash)
					goto L_ENTRY_HASH;
				
				lastHash = hash;
				
				foreach (HashInfo info ; hashInfo)
				{
					if (hash == info.tagName)
					{
						settings.select(info.type);
						goto L_ENTRY_HASH;
					}
				}
				
				printError(13, "Hash tag not found at line %u", currentLine);
				continue;
			case sri:
				throw new Exception("SRI is not supported in file checks");
			}
		
L_ENTRY_HASH:
			if (settings.hash(settings, file))
			{
				++statErrors;
				continue;
			}
			
			version (Trace) trace("r1=%s r2=%s", settings.result, result);
			
			import std.digest : secureEqual;
			if (secureEqual(settings.hasher.toHex, result) == false)
			{
				++statMismatch;
				writeln(file, ": FAILED");
				continue;
			}
			
			writeln(file, ": OK");
		}
	}
	catch (Exception ex)
	{
		return printError(15, ex);
	}
	
	if (statErrors || statMismatch)
		return printError(0, "%u mismatches, %u not read", statMismatch, statErrors);
	
	return 0;
}

// String for getopt
void showPage(string page)
{
	import core.stdc.stdlib : exit;
	switch (page)
	{
	case "ver": page = PROJECT_VERSION; break;
	case "version": page = PAGE_VERSION; break;
	case "license": page = PAGE_LICENSE; break;
	case "cofe": page = PAGE_COFE; break;
	default: assert(0);
	}
	writeln(page);
	exit(0);
}

void printMeta(string baseName, string name, string tagName)
{
	writefln("%-18s  %-18s  %s", baseName, name, tagName);
}

int main(string[] args)
{
	const size_t argc = args.length;
	Settings settings;	/// CLI arguments
	GetoptResult res = void;
	bool bsd, sri;
	
	try
	{
		res = getopt(args, config.caseInsensitive, config.passThrough,
		"F|file",     "Input mode: Regular file (default).", &settings.setEntryMode,
		"b|binary",   "File: Set binary mode (default).", &settings.setFileModeText,
		"t|text",     "File: Set text mode.", &settings.setFileModeBinary,
		"M|mmfile",   "Input mode: Memory-map file.", &settings.setEntryMode,
		"a|arg",      "Input mode: Command-line argument is text data (UTF-8).", &settings.setEntryMode,
		"c|check",    "Check hashes list in this file.", &settings.setEntryMode,
		"C|chunk",    "Set buffer size, affects file/mmfile/stdin (default=64K).", &settings.setBufferSize,
		"shallow",    "Depth: Same directory (default).", &settings.setSpanMode,
		"s|depth",    "Depth: Deepest directories first.", &settings.setSpanMode,
		"breadth",    "Depth: Sub directories first.", &settings.setSpanMode,
		"follow",     "Links: Follow symbolic links (default).", &settings.setFollow,
		"nofollow",   "Links: Do not follow symbolic links.", &settings.setNofollow,
		"tag",        "Create or read BSD-style hashes.", &bsd,
		"sri",        "Create or read SRI-style hashes.", &sri,
		"version",    "Show version page and quit.", &showPage,
		"ver",        "Show version and quit.", &showPage,
		"license",    "Show license page and quit.", &showPage,
		);
	}
	catch (Exception ex)
	{
		return printError(1, ex);
	}
	
	if (res.helpWanted)
	{
L_HELP:
		writeln(PAGE_HELP);
		foreach (Option opt; res.options)
		{
			with (opt) if (optShort)
				writefln("%s, %-12s  %s", optShort, optLong, help);
			else
				writefln("    %-12s  %s", optLong, help);
		}
		writeln("\nThis program has actual coffee-making abilities.");
		return 0;
	}
	
	if (argc < 2)
	{
		goto L_HELP;
	}
	
	string action = args[1];
	HashType type = cast(HashType)-1;
	
	// Aliases for hashes and checksums
	foreach (info; hashInfo)
	{
		if (action == info.aliasName)
		{
			type = info.type;
			break;
		}
	}
	
	// Pages
	if (type == -1)
	{
		switch (action)
		{
		case "list":
			printMeta("Alias", "Name", "Tag");
			foreach (info; hashInfo)
				printMeta(info.aliasName, info.fullName, info.tagName);
			return 0;
		case "help":
			goto L_HELP;
		case "ver", "version", "license", "cofe":
			showPage(action);
			return 0;
		default:
			return printError(1, "Unknown action '%s'", action);
		}
	}
	
	if (settings.select(type))
	{
		return printError(2, "Couldn't initiate hash module");
	}
	
	if (argc < 3)
		return entryStdin(settings);
	
	int function(ref Settings, string) entry = void;
	final switch (settings.method) with (EntryMethod)
	{
	case file: entry = &entryFile; version(Trace) trace("entryFile"); break;
	case list: entry = &entryList; version(Trace) trace("entryList"); break;
	case text: entry = &entryText; version(Trace) trace("entryText"); break;
	}
	
	if (bsd)
		settings.type = TagType.bsd;
	else if (sri)
		settings.type = TagType.sri;
	
	foreach (string arg; args[2..$])
	{
		if (arg == STDIN_NAME) // stdin
		{
			if (entryStdin(settings))
				return 2;
			continue;
		}
		
		entry(settings, arg);
	}
	
	return 0;
}

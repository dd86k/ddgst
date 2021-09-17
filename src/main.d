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
import ddh.ddh;

private:

enum PROJECT_VERSION = "1.0.0";
enum PROJECT_NAME    = "ddh";

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = [ "cleanup:none" ];

// The DRT CLI is pretty useless
extern (C) __gshared bool rt_cmdline_enabled = false;

debug enum BUILD_TYPE = "-debug";
else  enum BUILD_TYPE = "";

immutable string TEXT_VERSION =
PROJECT_NAME~` v`~PROJECT_VERSION~BUILD_TYPE~` (`~__TIMESTAMP__~`)
Compiler: `~__VENDOR__~" FE v"~format("%u.%03u", version_major, version_minor);

immutable string TEXT_HELP =
`Usage:
  ddh page
  ddh alias [-]
  ddh alias [options...] [{file|-}...]
`;

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

immutable string STDIN_NAME = "-";

enum DEFAULT_CHUNK_SIZE = 64 * 1024; // Seemed the best in benchmarks at least

enum EntryMethod { file, text, list }

struct Settings
{
	EntryMethod method;
	DDH_T ddh;
	char[] result;
	string listPath;
	ulong bufferSize = DEFAULT_CHUNK_SIZE;
	SpanMode spanMode;
	bool follow = true;
	bool textMode;
	
	int function(ref Settings, string) hash = &hashFile;
	
	int select(DDHType type)
	{
		if (ddh_init(ddh, type))
			return 2;
		return 0;
	}
	
	void setInputMode(string opt)
	{
		final switch (opt)
		{
		case "F|file":   hash = &hashFile; break;
		case "M|mmfile": hash = &hashMmfile; break;
		case "a|arg":	 hash = &hashText; break;
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
		bufferSize = v;
	}
	
	void setSpanMode(string opt)
	{
		final switch (opt)
		{
		case "s|depth": spanMode = SpanMode.depth; return;
		case "shallow": spanMode = SpanMode.shallow; return;
		case "breath": spanMode = SpanMode.breadth; return;
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

int printError(string func = __FUNCTION__, A...)(string fmt, A args)
{
	stderr.write(func, ": ");
	stderr.writefln(fmt, args);
	return 1;
}
int printError(ref Exception ex, string func = __FUNCTION__)
{
	debug stderr.writeln(ex);
	else  stderr.writefln("%s: %s", func, ex.msg);
	return 1;
}
void printResult(string fmt = "%s  %s")(char[] hash, in char[] file)
{
	writefln(fmt, hash, file);
}
version (Trace)
void trace(string func = __FUNCTION__, A...)(string fmt, A args)
{
	write(func, ": ");
	writefln(fmt, args);
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
	strtobin(&s, "1K");
	assert(s == 1024);
	strtobin(&s, "1.1K");
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
		return printError(ex);
	}
}
int hashFile(ref Settings settings, ref File file)
{
	try
	{
		foreach (ubyte[] chunk; file.byChunk(settings.bufferSize))
			ddh_compute(settings.ddh, chunk);
		
		settings.result = ddh_string(settings.ddh);
		ddh_reset(settings.ddh);
		return 0;
	}
	catch (Exception ex)
	{
		return printError(ex);
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
					ddh_compute(settings.ddh,
						cast(ubyte[])mmfile[start..start + settings.bufferSize]);
			}
			
			// Compute remaining
			ddh_compute(settings.ddh, cast(ubyte[])mmfile[start..flen]);
		}
		
		settings.result = ddh_string(settings.ddh);
		ddh_reset(settings.ddh);
		return 0;
	}
	catch (Exception ex)
	{
		return printError(ex);
	}
}
int hashStdin(ref Settings settings, string)
{
	version (Trace) trace("stdin");
	return hashFile(settings, stdin);
}
int hashText(ref Settings settings, string text)
{
	try
	{
		ddh_compute(settings.ddh, cast(ubyte[])text);
		settings.result = ddh_string(settings.ddh);
		ddh_reset(settings.ddh);
		return 0;
	}
	catch (Exception ex)
	{
		return printError(ex);
	}
}

int entryFile(ref Settings settings, string path)
{
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
			printError("'%s': Is a directory", file);
			continue;
		}
		if (settings.hash(settings, file))
		{
			continue;
		}
		printResult(settings.result, file);
	}
	if (count == 0)
		printError("'%s': No such file", name);
	return 0;
}
int entryStdin(ref Settings settings)
{
	int e = hashStdin(settings, STDIN_NAME);
	if (e == 0)
		printResult(settings.result, STDIN_NAME);
	return e;
}
int entryText(ref Settings settings, string text)
{
	int e = hashText(settings, text);
	if (e == 0)
		printResult!`%s  "%s"`(settings.result, text);
	return e;
}

int entryList(ref Settings settings, string listPath)
{
	import std.file : readText;
	import std.utf : UTFException;
	import std.algorithm.iteration : splitter;
	
	/// Number of characters the hash string.
	size_t hashsize = ddh_digest_size(settings.ddh) << 1;
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
		text.utf8 = readText(listPath);
	}
	catch (Exception ex)
	{
		return printError(ex);
	}
	
	size_t len = text.utf8.length;
	
	if (len == 0)
		return printError("File '%s' is empty", listPath);
	
	if (len < minsize)
		return printError("File '%s' too small", listPath);
	
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
		int e = settings.hash(settings, filepath);
		if (e)
		{
			++r_errors;
			continue;
		}
		
		// Compare hash/checksum
		if (line[0..hashsize] != settings.result)
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

void showPage(string setting)
{
	import core.stdc.stdlib : exit;
	switch (setting)
	{
	case "ver": writeln(PROJECT_VERSION); break;
	case "version": break;
	case "license": break;
	default: assert(0);
	}
	exit(0);
}

int main(string[] args)
{
	const size_t argc = args.length;
	Settings settings;	/// CLI arguments
	GetoptResult res = void;
	try
	{
		res = getopt(args, config.caseInsensitive, config.passThrough,
		"F|file",     "Input mode: Regular file (default)", &settings.setInputMode,
		"b|binary",   "  File: Set binary mode (default)", &settings.setFileModeText,
		"t|text",     "  File: Set text mode", &settings.setFileModeBinary,
		"M|mmfile",   "Input mode: Memory-map file (std.mmfile)", &settings.setInputMode,
		"a|arg",      "Input mode: Command-line argument text (utf-8)", &settings.setInputMode,
		"c|check",    "Check hashes list in this file", &settings.listPath,
		"C|chunk",    "Set chunk size, affects file/mmfile/stdin (default=64K)", &settings.setBufferSize,
		"shallow",    "Depth: Same directory (default)", &settings.setSpanMode,
		"s|depth",    "Depth: Deepest directories first", &settings.setSpanMode,
		"breadth",    "Depth: Sub directories first", &settings.setSpanMode,
		"follow",     "Links: Follow symbolic links (default)", &settings.setFollow,
		"nofollow",   "Links: Do not follow symbolic links", &settings.setNofollow,
		"version",    "Show version page and quit", &showPage,
		"ver",        "Show version and quit", &showPage,
		"license",    "Show license page and quit", &showPage,
		);
	}
	catch (Exception ex)
	{
		return printError(ex);
	}
	
	if (res.helpWanted)
	{
L_HELP:
		writeln(TEXT_HELP);
		foreach (Option opt; res.options)
		{
			with (opt) if (optShort)
				writefln("%s, %-12s  %s", optShort, optLong, help);
			else
				writefln("    %-12s  %s", optLong, help);
		}
		return 0;
	}
	
	if (argc < 2)
	{
		goto L_HELP;
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
			showPage("ver");
			return 0;
		case "help":
			goto L_HELP;
		case "version":
			showPage("version");
			return 0;
		case "license":
			showPage("license");
			return 0;
		default:
			return printError("Unknown action '%s'", action);
		}
	}
	
	if (settings.select(type))
	{
		printError("Couldn't initiate hash module");
		return 2;
	}
	
	if (argc < 3)
		return entryStdin(settings);
	
	int function(ref Settings, string) entry = void;
	final switch (settings.method)
	{
	case EntryMethod.file:  entry = &entryFile; break;
	case EntryMethod.list:  entry = &entryList; break;
	case EntryMethod.text:  entry = &entryText; break;
	}
	
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

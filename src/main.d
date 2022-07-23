/**
 * Command-line interface.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module main;

import std.compiler : version_major, version_minor;
import std.file : dirEntries, DirEntry, SpanMode;
import std.format : format, formattedRead;
import std.getopt;
import std.path : baseName, dirName;
import std.stdio;
import std.typecons : scoped;
import blake2d : BLAKE2D_VERSION_STRING;
import sha3d : SHA3D_VERSION_STRING;
import ddh;
import gitinfo;

private:

enum DEFAULT_READ_SIZE = 4 * 1024;
enum TagType { gnu, bsd, sri, plain }

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = [ "cleanup:none" ];

// Disables the Druntime GC command-line interface
// except for debug builds
debug {} else
extern (C) __gshared bool rt_cmdline_enabled = false;

debug enum BUILD_TYPE = "+debug";
else  enum BUILD_TYPE = "";

immutable string PAGE_VERSION =
`ddh `~GIT_DESCRIPTION[1..$]~BUILD_TYPE~` (built: `~__TIMESTAMP__~`)
Using sha3-d `~SHA3D_VERSION_STRING~`, blake2-d `~BLAKE2D_VERSION_STRING~`
No Copyrights
License: Unlicense
Homepage: <https://github.com/dd86k/ddh>
Compiler: `~__VENDOR__~" v"~format("%u.%03u", version_major, version_minor);

immutable string PAGE_HELP =
`Usage: ddh command [options...] [files...] [-]

Commands
check     Automatically check hash list depending on file extension.
list      List all supported hashes and checksums.
help      This help page and exit.
ver       Only show version number and exit.
version   Show version page and exit.

Options
--                Stop processing options.
--stdin           Input mode: Standard input (stdin).`;

immutable string PAGE_LICENSE =
`Creative Commons Legal Code

CC0 1.0 Universal

    CREATIVE COMMONS CORPORATION IS NOT A LAW FIRM AND DOES NOT PROVIDE
    LEGAL SERVICES. DISTRIBUTION OF THIS DOCUMENT DOES NOT CREATE AN
    ATTORNEY-CLIENT RELATIONSHIP. CREATIVE COMMONS PROVIDES THIS
    INFORMATION ON AN "AS-IS" BASIS. CREATIVE COMMONS MAKES NO WARRANTIES
    REGARDING THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS
    PROVIDED HEREUNDER, AND DISCLAIMS LIABILITY FOR DAMAGES RESULTING FROM
    THE USE OF THIS DOCUMENT OR THE INFORMATION OR WORKS PROVIDED
    HEREUNDER.

Statement of Purpose

The laws of most jurisdictions throughout the world automatically confer
exclusive Copyright and Related Rights (defined below) upon the creator
and subsequent owner(s) (each and all, an "owner") of an original work of
authorship and/or a database (each, a "Work").

Certain owners wish to permanently relinquish those rights to a Work for
the purpose of contributing to a commons of creative, cultural and
scientific works ("Commons") that the public can reliably and without fear
of later claims of infringement build upon, modify, incorporate in other
works, reuse and redistribute as freely as possible in any form whatsoever
and for any purposes, including without limitation commercial purposes.
These owners may contribute to the Commons to promote the ideal of a free
culture and the further production of creative, cultural and scientific
works, or to gain reputation or greater distribution for their Work in
part through the use and efforts of others.

For these and/or other purposes and motivations, and without any
expectation of additional consideration or compensation, the person
associating CC0 with a Work (the "Affirmer"), to the extent that he or she
is an owner of Copyright and Related Rights in the Work, voluntarily
elects to apply CC0 to the Work and publicly distribute the Work under its
terms, with knowledge of his or her Copyright and Related Rights in the
Work and the meaning and intended legal effect of CC0 on those rights.

1. Copyright and Related Rights. A Work made available under CC0 may be
protected by copyright and related or neighboring rights ("Copyright and
Related Rights"). Copyright and Related Rights include, but are not
limited to, the following:

  i. the right to reproduce, adapt, distribute, perform, display,
     communicate, and translate a Work;
 ii. moral rights retained by the original author(s) and/or performer(s);
iii. publicity and privacy rights pertaining to a person's image or
     likeness depicted in a Work;
 iv. rights protecting against unfair competition in regards to a Work,
     subject to the limitations in paragraph 4(a), below;
  v. rights protecting the extraction, dissemination, use and reuse of data
     in a Work;
 vi. database rights (such as those arising under Directive 96/9/EC of the
     European Parliament and of the Council of 11 March 1996 on the legal
     protection of databases, and under any national implementation
     thereof, including any amended or successor version of such
     directive); and
vii. other similar, equivalent or corresponding rights throughout the
     world based on applicable law or treaty, and any national
     implementations thereof.

2. Waiver. To the greatest extent permitted by, but not in contravention
of, applicable law, Affirmer hereby overtly, fully, permanently,
irrevocably and unconditionally waives, abandons, and surrenders all of
Affirmer's Copyright and Related Rights and associated claims and causes
of action, whether now known or unknown (including existing as well as
future claims and causes of action), in the Work (i) in all territories
worldwide, (ii) for the maximum duration provided by applicable law or
treaty (including future time extensions), (iii) in any current or future
medium and for any number of copies, and (iv) for any purpose whatsoever,
including without limitation commercial, advertising or promotional
purposes (the "Waiver"). Affirmer makes the Waiver for the benefit of each
member of the public at large and to the detriment of Affirmer's heirs and
successors, fully intending that such Waiver shall not be subject to
revocation, rescission, cancellation, termination, or any other legal or
equitable action to disrupt the quiet enjoyment of the Work by the public
as contemplated by Affirmer's express Statement of Purpose.

3. Public License Fallback. Should any part of the Waiver for any reason
be judged legally invalid or ineffective under applicable law, then the
Waiver shall be preserved to the maximum extent permitted taking into
account Affirmer's express Statement of Purpose. In addition, to the
extent the Waiver is so judged Affirmer hereby grants to each affected
person a royalty-free, non transferable, non sublicensable, non exclusive,
irrevocable and unconditional license to exercise Affirmer's Copyright and
Related Rights in the Work (i) in all territories worldwide, (ii) for the
maximum duration provided by applicable law or treaty (including future
time extensions), (iii) in any current or future medium and for any number
of copies, and (iv) for any purpose whatsoever, including without
limitation commercial, advertising or promotional purposes (the
"License"). The License shall be deemed effective as of the date CC0 was
applied by Affirmer to the Work. Should any part of the License for any
reason be judged legally invalid or ineffective under applicable law, such
partial invalidity or ineffectiveness shall not invalidate the remainder
of the License, and in such case Affirmer hereby affirms that he or she
will not (i) exercise any of his or her remaining Copyright and Related
Rights in the Work or (ii) assert any associated claims and causes of
action with respect to the Work, in either case contrary to Affirmer's
express Statement of Purpose.

4. Limitations and Disclaimers.

 a. No trademark or patent rights held by Affirmer are waived, abandoned,
    surrendered, licensed or otherwise affected by this document.
 b. Affirmer offers the Work as-is and makes no representations or
    warranties of any kind concerning the Work, express, implied,
    statutory or otherwise, including without limitation warranties of
    title, merchantability, fitness for a particular purpose, non
    infringement, or the absence of latent or other defects, accuracy, or
    the present or absence of errors, whether or not discoverable, all to
    the greatest extent permissible under applicable law.
 c. Affirmer disclaims responsibility for clearing rights of other persons
    that may apply to the Work or any use thereof, including without
    limitation any person's Copyright and Related Rights in the Work.
    Further, Affirmer disclaims responsibility for obtaining any necessary
    consents, permissions or other rights required for any use of the
    Work.
 d. Affirmer understands and acknowledges that Creative Commons is not a
    party to this document and has no duty or obligation with respect to
    this CC0 or use of the Work.`;

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

immutable string FILE_MODE_TEXT = "r";
immutable string FILE_MODE_BIN  = "rb";

struct Settings
{
	Ddh hasher;
	ubyte[] rawHash;
	string listPath;
	size_t bufferSize = DEFAULT_READ_SIZE;
	SpanMode spanMode;
	TagType tag;
	string fileMode = FILE_MODE_BIN;
	string against;	/// Hash to check against (-a/--against)
	
	int function(const(char)[]) hash = &hashFile;
	int function(const(char)[]) process = &processFile;
	
	bool follow = true;
	bool skipArgs;
	bool modeStdin;
}

__gshared Settings settings;

version (Trace)
void trace(string func = __FUNCTION__, A...)(string fmt, A args)
{
	write("TRACE:", func, ": ");
	writefln(fmt, args);
}

void printWarning(string func = __FUNCTION__, A...)(string fmt, A args)
{
	stderr.write("warning: ");
	debug stderr.write("[", func, "] ");
	stderr.writefln(fmt, args);
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

void printResult(string fmt = "%s")(in char[] file)
{
	enum fmtgnu = fmt ~ "  %s";
	enum fmtbsd = "%s(" ~ fmt ~ ")= %s";
	
	final switch (settings.tag) with (TagType)
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
	case plain:
		writeln(settings.hasher.toHex);
		break;
	}
}
void printStatus(in char[] file, bool match) {
	if (match)
		writeln(file, ": OK");
	else
		stderr.writeln(file, ": FAILED");
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
	
	enum LIMIT = 2 * G; /// Buffer read limit
	if (u > LIMIT)
		return 5;
	
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

bool compareHash(const(char)[] h1, const(char)[] h2)
{
	import std.digest : secureEqual;
	import std.uni : asLowerCase;
	return secureEqual(h1.asLowerCase, h2.asLowerCase);
}

int hashFile(const(char)[] path)
{
	version (Trace) trace("path=%s", path);
	
	try
	{
		File f;	// Must never be void
		// BUG: Using opAssign with LDC2 crashes at runtime
		f.open(cast(string)path, settings.fileMode);
		
		if (f.size())
		{
			int e = hashFile(f);
			if (e) return e;
		}
		
		f.close();
		return 0;
	}
	catch (Exception ex)
	{
		return printError(6, ex);
	}
}
int hashFile(ref File file)
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
int hashMmfile(const(char)[] path)
{
	import std.range : chunks;
	import std.mmfile : MmFile;
	
	version (Trace) trace("path=%s", path);
	
	try
	{
		auto mmfile = scoped!MmFile(cast(string)path);
		ulong flen = mmfile.length;
		
		if (flen)
		{
			foreach (chunk; chunks(cast(ubyte[])mmfile[], settings.bufferSize))
			{
				settings.hasher.put(chunk);
			}
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
int hashStdin(string)
{
	version (Trace) trace("stdin");
	return hashFile(stdin);
}
int hashText(const(char)[] text)
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

int processFile(const(char)[] path)
{
	version (Trace) trace("path=%s", path);
	
	uint count;
	string dir  = cast(string)dirName(path);  // "." if anything
	string name = cast(string)baseName(path); // Glob patterns are kept
	const bool same = dir == "."; // same directory name from dirName
	foreach (DirEntry entry; dirEntries(dir, name, settings.spanMode, settings.follow))
	{
		// Because entry will have "./" prefixed to it
		string file = same ? entry.name[2..$] : entry.name;
		++count;
		if (entry.isDir)
		{
			printWarning("'%s': Is a directory", file);
			continue;
		}
		
		if (settings.hash(file))
		{
			continue;
		}
		
		if (settings.against)
		{
			bool succ = void;
			if (settings.tag == TagType.sri)
			{
				const(char)[] type = void, hash = void;
				if (readSRILine(settings.against, type, hash))
					return printError(18, "Could not unformat SRI tag");
				settings.hasher.toBase64;
				succ = compareHash(settings.hasher.toBase64, hash);
			}
			else
			{
				succ = compareHash(
					settings.hasher.toHex, settings.against);
			}
			printStatus(file, succ);
			if (succ == false) return 2;
		}
		else
			printResult(file);
	}
	if (count == 0)
		return printError(6, "'%s': No such file", name);
	return 0;
}
int processStdin()
{
	version (Trace) trace("stdin");
	int e = hashStdin(STDIN_NAME);
	if (e == 0)
		printResult(STDIN_NAME);
	return e;
}
int processText(const(char)[] text)
{
	version (Trace) trace("text='%s'", text);
	int e = hashText(text);
	if (e == 0)
		printResult!`"%s"`(text);
	return e;
}

int processList(const(char)[] listPath)
{
	import std.file : readText;
	import std.string : lineSplitter;
	
	version (Trace) trace("list=%s", listPath);
	
	/// Minimum line length (hash + 1 spaces).
	// Example: abcd1234  file.txt
	uint currentLine, statMismatch, statErrors;
	
	try
	{
		string text = readText(listPath);
	
		if (text.length == 0)
			return printError(10, "%s: Empty", listPath);
		
		const(char)[] file = void, expected = void, type = void, lastType;
		foreach (string line; lineSplitter(text)) // doesn't allocate
		{
			++currentLine;
			
			if (line.length == 0) // empty
				continue;
			if (line[0] == '#') // comment
				continue;
			
			final switch (settings.tag) with (TagType)
			{
			case gnu:
				// Tested to work with one or many spaces
				if (readGNULine(line, expected, file))
				{
					++statErrors;
					printWarning("Unobtainable hash at line %u", currentLine);
					continue;
				}
				break;
			case bsd:
				// Tested to work with and without spaces
				//if (formattedRead(line, "%s(%s) = %s", type, file, expected) != 3)
				if (readBSDLine(line, type, file, expected))
				{
					++statErrors;
					printWarning("Unobtainable hash at line %u", currentLine);
					continue;
				}
				
				if (type == lastType)
					goto L_ENTRY_HASH;
				
				lastType = type;
				
				foreach (HashInfo info ; hashInfo)
				{
					if (type == info.tagName)
					{
						settings.hasher.initiate(info.type);
						goto L_ENTRY_HASH;
					}
				}
				
				printWarning("Unknown hash tag at line %u", currentLine);
				continue;
			case sri:
				return printError(15, "SRI format is not supported in file checks");
			case plain:
				return printError(15, "Plain format is not supported in file checks");
			}
		
L_ENTRY_HASH:
			if (settings.hash(file))
			{
				++statErrors;
				continue;
			}
			
			const(char)[] result = settings.hasher.toHex;
			
			version (Trace) trace("r1=%s r2=%s", result, expected);
			
			if (compareHash(result, expected) == false)
			{
				++statMismatch;
				printStatus(file, false);
				continue;
			}
			
			printStatus(file, true);
		}
	}
	catch (Exception ex)
	{
		return printError(15, ex);
	}
	
	if (statErrors || statMismatch)
		writefln("%u mismatches, %u not read", statMismatch, statErrors);
	
	return 0;
}

//TODO: Consider making a foreach-compatible function for this
//      popFront returning T[2] (or tuple)
/// Compare all file entries against each other.
/// BigO: O(n * log(n)) (according to friend)
/// Params: entries: List of files
/// Returns: Error code.
int processCompare(string[] entries)
{
	const size_t size = entries.length;
	
	if (size < 2)
		return printError(1, "Comparison needs 2 or more files");
	
	//TODO: Consider an associated array
	//      Would remove duplicates, but at the same time, this removes
	//      all user-supplied positions and may confuse people.
	string[] hashes = new string[size];
	
	for (size_t index; index < size; ++index)
	{
		int e = hashFile(entries[index]);
		if (e) return e;
		
		hashes[index] = settings.hasher.toHex.idup;
	}
	
	uint mismatch;	/// Number of mismatching files
	
	for (size_t distance = 1; distance < size; ++distance)
	{
		for (size_t index; index < size; ++index)
		{
			size_t index2 = index + distance;
			
			if (index2 >= size)
				break;
			
			if (compareHash(hashes[index], hashes[index2]))
				continue;
			
			++mismatch;
			
			string entry1 = entries[index];
			string entry2 = entries[index2];
			
			writeln("Files '", entry1, "' and '", entry2, "' are different");
		}
	}

	if (mismatch == 0)
		writefln("All files identical");
	
	return 0;
}

void printMeta(string baseName, string name, string tagName)
{
	writefln("%-18s  %-18s  %s", baseName, name, tagName);
}

immutable string OPT_FILE	= "f|file";
immutable string OPT_MMFILE	= "m|mmfile";
immutable string OPT_STDIN	= "stdin";
immutable string OPT_ARG	= "a|arg";
immutable string OPT_CHECK	= "c|check";
immutable string OPT_TEXT	= "t|text";
immutable string OPT_BINARY	= "b|binary";
immutable string OPT_BUFFERSIZE	= "B|buffersize";
immutable string OPT_GNU	= "gnu";
immutable string OPT_TAG	= "tag";
immutable string OPT_SRI	= "sri";
immutable string OPT_PLAIN	= "plain";
immutable string OPT_FOLLOW	= "follow";
immutable string OPT_NOFOLLOW	= "nofollow";
immutable string OPT_DEPTH	= "r|depth";
immutable string OPT_SHALLOW	= "shallow";
immutable string OPT_BREATH	= "breath";
immutable string OPT_VER	= "ver";
immutable string OPT_VERSION	= "version";
immutable string OPT_LICENSE	= "license";
immutable string OPT_COFE	= "cofe";

void option(string arg)
{
	import core.stdc.stdlib : exit;
	
	version (Trace) trace(arg);
	
	with (settings) final switch (arg)
	{
	// input modes
	case OPT_ARG:   process = &processText; return;
	case OPT_CHECK: process = &processList; return;
	case OPT_STDIN: settings.modeStdin = true; return;
	// file input mode
	case OPT_FILE:   hash = &hashFile; return;
	case OPT_MMFILE: hash = &hashMmfile; return;
	case OPT_TEXT:   fileMode = FILE_MODE_TEXT; return;
	case OPT_BINARY: fileMode = FILE_MODE_BIN; return;
	// hash style
	case OPT_TAG:   tag = TagType.bsd; return;
	case OPT_SRI:   tag = TagType.sri; return;
	case OPT_GNU:   tag = TagType.gnu; return;
	case OPT_PLAIN: tag = TagType.plain; return;
	// globber: symlink
	case OPT_NOFOLLOW: follow = false; return;
	case OPT_FOLLOW:   follow = true; return;
	// globber: directory
	case OPT_DEPTH:   spanMode = SpanMode.depth; return;
	case OPT_SHALLOW: spanMode = SpanMode.shallow; return;
	case OPT_BREATH:  spanMode = SpanMode.breadth; return;
	// pages
	case OPT_VER:     arg = GIT_DESCRIPTION; break;
	case OPT_VERSION: arg = PAGE_VERSION; break;
	case OPT_LICENSE: arg = PAGE_LICENSE; break;
	case OPT_COFE:    arg = PAGE_COFE; break;
	}
	writeln(arg);
	exit(0);
}

void option2(string arg, string val)
{
	with (settings) final switch (arg)
	{
	case OPT_BUFFERSIZE:
		ulong v = void;
		if (strtobin(&v, val))
			throw new GetOptException("Couldn't unformat buffer size");
		version (D_LP64) {}
		else {
			if (v >= uint.max)
				throw new GetOptException("Buffer size overflows");
		}
		bufferSize = cast(size_t)v;
		return;
	}
}

int main(string[] args)
{
	bool compare;
	
	GetoptResult res = void;
	try
	{
		res = getopt(args, config.caseSensitive,
		OPT_FILE,       "Input mode: Regular file (default).", &option,
		OPT_BINARY,     "File: Set binary mode (default).", &option,
		OPT_TEXT,       "File: Set text mode.", &option,
		OPT_MMFILE,     "Input mode: Memory-map file.", &option,
		OPT_ARG,        "Input mode: Command-line argument is text data (UTF-8).", &option,
		OPT_STDIN,      "Input mode: Standard input (stdin)", &option,
		OPT_CHECK,      "Check hashes list in this file.", &option,
		"C|compare",    "Compares all file entries.", &compare,
		"A|against",    "Compare files against hash.", &settings.against,
		OPT_BUFFERSIZE, "Set buffer size, affects file/mmfile/stdin (default=4K).", &option2,
		OPT_SHALLOW,    "Depth: Same directory (default).", &option,
		OPT_DEPTH,      "Depth: Deepest directories first.", &option,
		OPT_BREATH,     "Depth: Sub directories first.", &option,
		OPT_FOLLOW,     "Links: Follow symbolic links (default).", &option,
		OPT_NOFOLLOW,   "Links: Do not follow symbolic links.", &option,
		OPT_TAG,        "Create or read BSD-style hashes.", &option,
		OPT_SRI,        "Create or read SRI-style hashes.", &option,
		OPT_PLAIN,      "Create or read plain hashes.", &option,
		OPT_VERSION,    "Show version page and quit.", &option,
		OPT_VER,        "Show version and quit.", &option,
		OPT_LICENSE,    "Show license page and quit.", &option,
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
	
	if (args.length < 2) // Missing hash type or action
	{
		return printError(1,
			"Missing hash type or action. Invoke with --help for more information.");
	}
	
	string action = args[1];
	
	HashType type = InvalidHash;
	
	switch (action)
	{
	case "check":
		if (args.length == 0)
			return printError(1, "Missing SUM file");
		
		type = guessHashExt(args[2]);
		if (type == InvalidHash)
			return printError(2, "Could not determine hash type");
		
		settings.process = &processList;
		
		break;
	case "list":
		static immutable sep = "--------";
		printMeta("Alias", "Name", "Tag");
		printMeta(sep, sep, sep);
		foreach (info; hashInfo)
			printMeta(info.alias_, info.fullName, info.tagName);
		return 0;
	case "help":
		goto L_HELP;
	case OPT_VER, OPT_VERSION, OPT_LICENSE, OPT_COFE:
		option(action);
		return 0;
	default:
		foreach (info; hashInfo)
		{
			if (action == info.alias_)
			{
				type = info.type;
				break;
			}
		}
	}
	
	// Pages
	if (type == InvalidHash)
	{
		return printError(1, "Unknown action or hash '%s'", action);
	}
	
	if (settings.hasher.initiate(type))
	{
		return printError(2, "Couldn't initiate hash module");
	}
	
	if (settings.modeStdin)
	{
		return processStdin;
	}

	string[] entries = args[2..$];
	
	if (entries.length == 0)
		return processStdin();
	
	if (compare)
		return processCompare(entries);
	
	foreach (string entry; entries)
	{
		settings.process(entry);
	}
	
	return 0;
}

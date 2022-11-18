/// Command-line interface.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module main;

import std.compiler : version_major, version_minor;
import std.file : dirEntries, DirEntry, SpanMode, read;
import std.format : format, formattedRead;
import std.getopt;
import std.path : baseName, dirName;
import std.stdio;
import std.typecons : scoped;
import core.stdc.stdlib : exit;
import blake2d : BLAKE2D_VERSION_STRING;
import sha3d : SHA3D_VERSION_STRING;
import ddh;
import gitinfo;

private:

alias readAll = read;

// GDC isn't happy with int*
extern(C) int sscanf(scope const char* s, scope const char* format, scope ...);

// Leave GC enabled, but avoid cleanup on exit
extern (C) __gshared string[] rt_options = ["cleanup:none"];

debug {} else
{
    // Disables the Druntime GC command-line interface
    // except for debug builds
    extern (C) __gshared bool rt_cmdline_enabled = false;
}

enum DEFAULT_READ_SIZE = 4 * 1024;
enum TagType
{
    gnu,
    bsd,
    sri,
    plain
}

debug enum BUILD_TYPE = "+debug";
else enum BUILD_TYPE = "";

immutable string PAGE_VERSION =
`ddh ` ~ GIT_DESCRIPTION ~ BUILD_TYPE ~ ` (built: ` ~ __TIMESTAMP__ ~ `)
Using sha3-d ` ~ SHA3D_VERSION_STRING ~ `, blake2-d ` ~ BLAKE2D_VERSION_STRING ~ `
No rights reserved
License: CC0
Homepage: <https://github.com/dd86k/ddh>
Compiler: ` ~ __VENDOR__ ~ " v" ~ format("%u.%03u", version_major, version_minor);

immutable string PAGE_HELP =
`Usage: ddh [options...|--autocheck] [files...|--stdin]

Options
    --            Stop processing options.`;

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
immutable string FILE_MODE_BIN = "rb";

immutable string OPT_FILE       = "f|file";
immutable string OPT_MMFILE     = "m|mmfile";
immutable string OPT_ARG        = "a|arg";
immutable string OPT_CHECK      = "c|check";
immutable string OPT_TEXT       = "t|text";
immutable string OPT_BINARY     = "b|binary";
immutable string OPT_BUFFERSIZE = "B|buffersize";
immutable string OPT_GNU        = "gnu";
immutable string OPT_TAG        = "tag";
immutable string OPT_SRI        = "sri";
immutable string OPT_PLAIN      = "plain";
immutable string OPT_FOLLOW     = "follow";
immutable string OPT_NOFOLLOW   = "nofollow";
immutable string OPT_DEPTH      = "r|depth";
immutable string OPT_SHALLOW    = "shallow";
immutable string OPT_BREATH     = "breath";
immutable string OPT_KEY        = "key";
//immutable string OPT_KEYFILE	= "keyfile";
//immutable string OPT_KEYBIN	= "keyhex";
immutable string OPT_SEED       = "seed";
immutable string OPT_VER        = "ver";
immutable string OPT_VERSION    = "version";
immutable string OPT_LICENSE    = "license";
immutable string OPT_COFE       = "cofe";

struct Settings
{
    Ddh hasher;
    HashType type = InvalidHash;
    ubyte[] rawHash;
    size_t bufferSize = DEFAULT_READ_SIZE;
    SpanMode spanMode;
    TagType tag;
    string fileMode = FILE_MODE_BIN;
    string against; /// Hash to check against (-a/--against)
    ubyte[] key; /// Key for BLAKE2
    uint seed; /// Seed for Murmurhash3

    int function(const(char)[]) hash = &hashFile;
    // entry processor (file, text, list)
    int function(const(char)[]) process = &processFile;

    bool follow = true;
    bool modeStdin;
    bool autocheck;
}

__gshared Settings settings;

version (Trace) void trace(string func = __FUNCTION__, A...)(string fmt, A args)
{
    write("TRACE:", func, ": ");
    writefln(fmt, args);
}

void logWarn(string func = __FUNCTION__, A...)(string fmt, A args)
{
    stderr.write("warning: ");
    debug stderr.write("[", func, "] ");
    stderr.writefln(fmt, args);
}

void logWarn(Exception ex)
{
    stderr.writefln("warning: %s", ex.msg);
}

void logError(string func = __FUNCTION__, A...)(int code, string fmt, A args)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.write("[", func, "] ");
    stderr.writefln(fmt, args);
    exit(code);
}

void logError(int code, Exception ex)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.writeln(ex);
    else stderr.writeln(ex.msg);
    exit(code);
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

void printStatus(in char[] file, bool match)
{
    if (match)
        writeln(file, ": OK");
    else
        stderr.writeln(file, ": FAILED");
}

// String to binary size
int strtobin(ulong* size, string input)
{
    enum
    {
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

    if (f <= 0.0f)
        return 3;

    ulong u = cast(ulong) f;
    switch (c)
    {
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

// unformat any number
uint unformat(string input)
{
    //import core.stdc.stdio : sscanf;
    import std.string : toStringz;

    int n = void;
    sscanf(input.toStringz, "%i", &n);
    return cast(uint) n;
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
        File f; // Must be init
        // BUG: Using opAssign with LDC2 crashes at runtime
        f.open(cast(string)path, settings.fileMode);
        
        if (f.size())
        {
            int e = hashFile(f);
            if (e)
                return e;
        }
        else // Nothing to process, finish digest
        {
            settings.rawHash = settings.hasher.finish();
            settings.hasher.reset();
        }
        
        f.close();
        return 0;
    }
    catch (Exception ex)
    {
        logWarn(ex);
        return 1;
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
        logWarn(ex);
        return 1;
    }
}

int hashMmfile(const(char)[] path)
{
    import std.range : chunks;
    import std.mmfile : MmFile;
    import std.file : getSize;

    version (Trace) trace("path=%s", path);

    try
    {
        ulong size = getSize(path);
        
        if (size)
        {
            auto mmfile = scoped!MmFile(cast(string)path);
            
            foreach (chunk; chunks(cast(ubyte[]) mmfile[], settings.bufferSize))
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
        logWarn(ex);
        return 1;
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
        settings.hasher.put(cast(ubyte[]) text);
        settings.rawHash = settings.hasher.finish();
        settings.hasher.reset();
        return 0;
    }
    catch (Exception ex)
    {
        logError(9, "Could not hash text: %s", ex.msg);
        return 0;
    }
}

int processFile(const(char)[] path)
{
    version (Trace) trace("path=%s", path);

    uint count;
    string dir  = cast(string)dirName(path); // "." if anything
    string name = cast(string)baseName(path); // Glob patterns are kept
    const bool same = dir == "."; // same directory name from dirName
    foreach (DirEntry entry; dirEntries(dir, name, settings.spanMode, settings.follow))
    {
        // Because entry will have "./" prefixed to it
        string file = same ? entry.name[2 .. $] : entry.name;
        ++count;
        if (entry.isDir)
        {
            logWarn("'%s': Is a directory", file);
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
                    logError(20, "Could not unformat SRI tag");
                
                settings.hasher.toBase64;
                succ = compareHash(settings.hasher.toBase64, hash);
            }
            else
            {
                succ = compareHash(settings.hasher.toHex, settings.against);
            }
            printStatus(file, succ);
            if (succ == false)
                return 2;
        }
        else
            printResult(file);
    }
    
    if (count == 0)
        logError(6, "'%s': No such file", name);
    
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

    uint currentLine, statMismatch, statErrors, statsTotal;
    
    if (settings.autocheck)
    {
        settings.type = guessHash(listPath);
        if (settings.type == InvalidHash)
            logError(5, "Could not determine hash type");
    }

    try
    {
        string text = readText(listPath);

        if (text.length == 0)
            logError(10, "%s: Empty", listPath);

        const(char)[] file = void, expected = void, type = void, lastType;
        foreach (string line; lineSplitter(text)) // doesn't allocate
        {
            ++currentLine;

            if (line.length == 0) // empty
                continue;
            if (line[0] == '#') // comment
                continue;

            TAGTYPE: final switch (settings.tag) with (TagType)
            {
            case gnu:
                if (readGNULine(line, expected, file))
                {
                    ++statErrors;
                    logWarn("Could not read GNU tag at line %u", currentLine);
                }
                
                if (file[0] == '*')
                    file = file[1..$];
                break;
            case bsd:
                if (readBSDLine(line, type, file, expected))
                {
                    ++statErrors;
                    logWarn("Could not read BSD tag at line %u", currentLine);
                    continue;
                }

                if (type == lastType)
                    break;

                // Find new hash type from tag name
                lastType = type;
                foreach (HashInfo info; hashInfo)
                {
                    if (type == info.tag)
                    {
                        settings.hasher.initiate(info.type);
                        break TAGTYPE;
                    }
                    if (type == info.tag2)
                    {
                        settings.hasher.initiate(info.type);
                        break TAGTYPE;
                    }
                }

                logWarn("Unknown '%s' tag at line %u", type, currentLine);
                continue;
            case sri:
                logError(11, "SRI hash format is not supported in file checks");
                break;
            case plain:
                logError(11, "Plain hash format is not supported in file checks");
                break;
            }
            
            ++statsTotal;

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
        logError(12, ex);
    }

    writefln("%u total: %u mismatches, %u not read",
        statsTotal, statMismatch, statErrors);

    return 0;
}

//TODO: Consider making a foreach-compatible function for this
//      popFront returning T[2] (or tuple)
/// Compare all file entries against each other.
/// O: O(n * log(n)) (according to friend)
/// Params: entries: List of files
/// Returns: Error code.
int processCompare(string[] entries)
{
    const size_t size = entries.length;

    if (size < 2)
        logError(15, "Comparison needs 2 or more files");

    //TODO: Consider an associated array
    //      Would remove duplicates, but at the same time, this removes
    //      all user-supplied positions and may confuse people if unordered.
    string[] hashes = new string[size];

    for (size_t index; index < size; ++index)
    {
        int e = hashFile(entries[index]);
        if (e)
            return e;

        hashes[index] = settings.hasher.toHex.idup;
    }

    uint mismatch; /// Number of mismatching files

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

void printMeta(string baseName, string name, string tag, string tag2)
{
    writefln("%-18s  %-18s  %-18s  %s", baseName, name, tag, tag2);
}

// special settings that getopts cannot simply set directly
void option(string arg)
{
    version (Trace) trace(arg);

    with (settings) final switch (arg)
    {
    // input modes
    case OPT_ARG:   process = &processText; return;
    case OPT_CHECK: process = &processList; return;
    // file input mode
    case OPT_FILE:      hash = &hashFile; return;
    case OPT_MMFILE:    hash = &hashMmfile; return;
    case OPT_TEXT:      fileMode = FILE_MODE_TEXT; return;
    case OPT_BINARY:    fileMode = FILE_MODE_BIN; return;
    // hash style
    case OPT_TAG:   tag = TagType.bsd; return;
    case OPT_SRI:   tag = TagType.sri; return;
    case OPT_GNU:   tag = TagType.gnu; return;
    case OPT_PLAIN: tag = TagType.plain; return;
    // globber: symlink
    case OPT_NOFOLLOW:  follow = false; return;
    case OPT_FOLLOW:    follow = true; return;
    // globber: directory
    case OPT_DEPTH:     spanMode = SpanMode.depth; return;
    case OPT_SHALLOW:   spanMode = SpanMode.shallow; return;
    case OPT_BREATH:    spanMode = SpanMode.breadth; return;
    // pages
    case OPT_VER:       arg = GIT_DESCRIPTION; break;
    case OPT_VERSION:   arg = PAGE_VERSION; break;
    case OPT_LICENSE:   arg = PAGE_LICENSE; break;
    case OPT_COFE:      arg = PAGE_COFE; break;
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
        
        if (v >= size_t.max)
            throw new GetOptException("Buffer size overflows");
        
        bufferSize = cast(size_t) v;
        return;
    // keying
    case OPT_KEY:
        try
        {
            settings.key = cast(ubyte[]) readAll(val);
        }
        catch (Exception ex)
        {
            throw new GetOptException(ex.msg);
        }
        return;
    // seeding
    case OPT_SEED:
        settings.seed = unformat(val);
        return;
    }
}

int cliAutoCheck(string[] entries)
{
    foreach (string entry; entries)
    {
        version (Trace) trace("entry=%s", entry);
        
        settings.type = guessHash(entry);
        if (settings.type == InvalidHash)
            logError(7, "Could not determine hash type for: %s", entry);
        
        if (settings.hasher.initiate(settings.type))
        {
            logError(3, "Couldn't initiate hash module");
        }
        
        processList(entry);
    }
    
    return 0;
}

void cliHashes()
{
    static immutable string sep = "-----------";
    printMeta("Alias", "Name", "Tag", "Tag2");
    printMeta(sep, sep, sep, sep);
    foreach (info; hashInfo)
        printMeta(info.alias_, info.fullName, info.tag, info.tag2);
    exit(0);
}

void cliHash(string opt)
{
    final switch (opt)
    {
    case crc32:     settings.type = HashType.CRC32; return;
    case crc64iso:  settings.type = HashType.CRC64ISO; return;
    case crc64ecma: settings.type = HashType.CRC64ECMA; return;
    case murmur3a:  settings.type = HashType.MurmurHash3_32; return;
    case murmur3c:  settings.type = HashType.MurmurHash3_128_32; return;
    case murmur3f:  settings.type = HashType.MurmurHash3_128_64; return;
    case md5:       settings.type = HashType.MD5; return;
    case ripemd160: settings.type = HashType.RIPEMD160; return;
    case sha1:      settings.type = HashType.SHA1; return;
    case sha224:    settings.type = HashType.SHA224; return;
    case sha256:    settings.type = HashType.SHA256; return;
    case sha384:    settings.type = HashType.SHA384; return;
    case sha512:    settings.type = HashType.SHA512; return;
    case sha3_224:  settings.type = HashType.SHA3_224; return;
    case sha3_256:  settings.type = HashType.SHA3_256; return;
    case sha3_384:  settings.type = HashType.SHA3_384; return;
    case sha3_512:  settings.type = HashType.SHA3_512; return;
    case shake128:  settings.type = HashType.SHAKE128; return;
    case shake256:  settings.type = HashType.SHAKE256; return;
    case blake2b512:    settings.type = HashType.BLAKE2b512; return;
    case blake2s256:    settings.type = HashType.BLAKE2s256; return;
    }
}

int main(string[] args)
{
    bool compare;

    GetoptResult res = void;
    try
    {
        //TODO: Array of bool to select multiple hashes?
        //TODO: Include argument (string,string) for doing batches with X hash?
        res = getopt(args, config.caseSensitive,
            OPT_COFE,       "", &option,
            crc32,          "", &cliHash,
            crc64iso,       "", &cliHash,
            crc64ecma,      "", &cliHash,
            murmur3a,       "", &cliHash,
            murmur3c,       "", &cliHash,
            murmur3f,       "", &cliHash,
            md5,            "", &cliHash,
            ripemd160,      "", &cliHash,
            sha1,           "", &cliHash,
            sha224,         "", &cliHash,
            sha256,         "", &cliHash,
            sha384,         "", &cliHash,
            sha512,         "", &cliHash,
            sha3_224,       "", &cliHash,
            sha3_256,       "", &cliHash,
            sha3_384,       "", &cliHash,
            sha3_512,       "", &cliHash,
            shake128,       "", &cliHash,
            shake256,       "", &cliHash,
            blake2b512,     "", &cliHash,
            blake2s256,     "", &cliHash,
            OPT_FILE,       "Input mode: Regular file (default).", &option,
            OPT_BINARY,     "File: Set binary mode (default).", &option,
            OPT_TEXT,       "File: Set text mode.", &option,
            OPT_MMFILE,     "Input mode: Memory-map file.", &option,
            OPT_ARG,        "Input mode: Command-line argument is text data (UTF-8).", &option,
            "stdin",        "Input mode: Standard input (stdin)", &settings.modeStdin,
            OPT_CHECK,      "Check hashes list in this file.", &option,
            "autocheck",    "Automatically determine hash type and process list.", &settings.autocheck,
            "C|compare",    "Compares all file entries.", &compare,
            "A|against",    "Compare files against hash.", &settings.against,
            "hashes",       "List supported hashes.", &cliHashes,
            OPT_BUFFERSIZE, "Set buffer size, affects file/mmfile/stdin (default=4K).", &option2,
            OPT_SHALLOW,    "Depth: Same directory (default).", &option,
            OPT_DEPTH,      "Depth: Deepest directories first.", &option,
            OPT_BREATH,     "Depth: Sub directories first.", &option,
            OPT_FOLLOW,     "Links: Follow symbolic links (default).", &option,
            OPT_NOFOLLOW,   "Links: Do not follow symbolic links.", &option,
            OPT_TAG,        "Create or read BSD-style hashes.", &option,
            OPT_SRI,        "Create or read SRI-style hashes.", &option,
            OPT_PLAIN,      "Create or read plain hashes.", &option,
            OPT_KEY,        "Binary key file for BLAKE2 hashes.", &option2,
            //"keyhex",       "Hex text key file for supported hash.",  &option2,
            //"keystr",       "Hex text argument for supported hash.",  &option2,
            OPT_SEED,       "Seed literal argument for Murmurhash3 hashes.", &option2,
            OPT_VERSION,    "Show version page and quit.", &option,
            OPT_VER,        "Show version and quit.", &option,
            OPT_LICENSE,    "Show license page and quit.", &option,
        );
    }
    catch (Exception ex)
    {
        logError(1, ex);
    }

    if (res.helpWanted)
    {
        writeln(PAGE_HELP);
        foreach (Option opt; res.options[HashCount + 1..$])
        {
            with (opt)
                if (optShort)
                    writefln("%s, %-12s  %s", optShort, optLong, help);
                else
                    writefln("    %-12s  %s", optLong, help);
        }
        writeln("\nThis program has actual coffee-making abilities.");
        return 0;
    }
    
    if (settings.autocheck)
    {
        return cliAutoCheck(args[1..$]);
    }

    if (settings.type == InvalidHash)
    {
        logError(2, "No hashes selected");
    }

    if (settings.hasher.initiate(settings.type))
    {
        logError(3, "Couldn't initiate hash module");
    }

    if (settings.key != settings.key.init)
    {
        try
        {
            settings.hasher.key(settings.key);
        }
        catch (Exception ex)
        {
            logError(4, "Failed to set key: %s", ex.msg);
        }
    }

    if (settings.seed)
    {
        try
        {
            settings.hasher.seed(settings.seed);
        }
        catch (Exception ex)
        {
            logError(5, "Failed to set seed: %s", ex.msg);
        }
    }

    if (settings.modeStdin)
    {
        return processStdin;
    }

    string[] entries = args[1 .. $];

    if (compare)
        return processCompare(entries);

    if (entries.length == 0)
        return processStdin;

    foreach (string entry; entries)
    {
        settings.process(entry);
    }

    return 0;
}

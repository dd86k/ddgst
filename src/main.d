/// Command-line interface.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module main;

import core.stdc.stdlib : exit;
import core.bitop : bswap;
import std.array : join;
import std.conv : text;
import std.datetime.stopwatch;
import std.digest : secureEqual;
import std.file;
import std.format : format;
import std.getopt;
import std.path : baseName, dirName;
import std.stdio;
import std.string : lineSplitter;
import std.traits : EnumMembers;
import ddgst, mtdir, reader, utils;
import printers;

// NOTE: secureEqual usage
//       In the case where someone is using this utility on a server,
//       it's simply better being safe than sorry.

private:
enum APPVERSION = "3.0.1";

debug
{
    enum BUILD_TYPE = "+debug";
}
else
{
    enum BUILD_TYPE = "";
    // Disables the Druntime GC command-line interface
    // except for debug builds
    extern (C) __gshared bool rt_cmdline_enabled = false;
    // Disable runtime environment variables
    extern (C) __gshared bool rt_envvars_enabled = false;
    // Leave GC enabled, but avoid cleanup on exit
    extern (C) __gshared string[] rt_options = [ "cleanup:none" ];
}

enum // Error codes
{
    ECLI        = 1,    /// CLI error
    ENOHASH     = 2,    /// No hashes selected or autocheck not used
    EINTERNAL   = 3,    /// Internal error
    ENOKEY      = 4,    /// Failed to set the hash key
    ENOSEED     = 5,    /// Failed to set the hash seed
    ENOARGS     = 6,    /// Missing entries
    ENOTEXT     = 9,    /// Could not hash text argument
    ENOLIST     = 10,   /// List is empty
    ENOSTYLE    = 11,   /// Unsupported style format
    ENOCMP      = 15,   /// Two or more files are required to compare
}

alias readAll = std.file.read;

immutable string D_COMPILER = format("%s v%u.%03u", __VENDOR__, __VERSION__/1000, __VERSION__%1000);

immutable string PAGE_HELP =
`USAGE

Hash files or stdin:
  ddgst --HASH [FILES...|-] [options...]

Compare files from a list:
  ddgst --HASH --check LIST [options...]
  ddgst --autocheck LIST [options...]

Compare files against a digest:
  ddgst --HASH --against=digest FILES... [options...]

Compare files against each other:
  ddgst --HASH --compare FILES... [options...]

Hash arguments as text data:
  ddgst --HASH --args TEXT... [options...]

Options:
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
     _____
   _|     |
  / |     |
  \_|     |
    |_____|
SECRET";

struct HasherOptions
{
    Hash hash;
    Style style;
    
    size_t buffersize = MiB!1;
    uint seed;
    ubyte[] key;
    SpanMode span;
    ubyte[] against;
    
    bool nofollow;
    bool autodetect;
    bool benchmark;
    bool hidestats;
    
    int threads = 1;
}

// App mode
enum Mode
{
    // Hash files/folders, default
    file,
    // Check files against list
    list,
    // Check digest against file(s)
    against,
    // Input data is text
    text,
    // Compare files between each other
    compare,
}

//
// Digest management
//

Digest newDigest(Hash hash, uint seed, ubyte[] key)
{
    // NOTE: Using multiple switches is fine for now...
    Digest digest = void;
    final switch (hash) with (Hash) {
    case crc32:                 digest = new CRC32Digest(); break;
    case crc64iso:              digest = new CRC64ISODigest(); break;
    case crc64ecma:             digest = new CRC64ECMADigest(); break;
    case murmurhash3_32:        digest = new MurmurHash3_32_SeededDigest(); break;
    case murmurhash3_128_32:    digest = new MurmurHash3_128_32_SeededDigest(); break;
    case murmurhash3_128_64:    digest = new MurmurHash3_128_64_SeededDigest(); break;
    case md5:                   digest = new MD5Digest(); break;
    case ripemd160:             digest = new RIPEMD160Digest(); break;
    case sha1:                  digest = new SHA1Digest(); break;
    case sha224:                digest = new SHA224Digest(); break;
    case sha256:                digest = new SHA256Digest(); break;
    case sha384:                digest = new SHA384Digest(); break;
    case sha512:                digest = new SHA512Digest(); break;
    case sha512_224:            digest = new SHA512_224Digest(); break;
    case sha512_256:            digest = new SHA512_256Digest(); break;
    case sha3_224:              digest = new SHA3_224Digest(); break;
    case sha3_256:              digest = new SHA3_256Digest(); break;
    case sha3_384:              digest = new SHA3_384Digest(); break;
    case sha3_512:              digest = new SHA3_512Digest(); break;
    case shake128:              digest = new SHAKE128Digest(); break;
    case shake256:              digest = new SHAKE256Digest(); break;
    case blake2s256:            digest = new BLAKE2s256Digest(); break;
    case blake2b512:            digest = new BLAKE2b512Digest(); break;
    case none:                  assert(false, "Not supposed to happen!");
    }
    if (seed)
    {
        switch (hash) with (Hash) {
        case murmurhash3_32:
            (cast(MurmurHash3_32_SeededDigest)digest).seed(seed);
            break;
        case murmurhash3_128_32:
            (cast(MurmurHash3_128_32_SeededDigest)digest).seed(seed);
            break;
        case murmurhash3_128_64:
            (cast(MurmurHash3_128_64_SeededDigest)digest).seed(seed);
            break;
        default:
            logError(ENOSEED, "Digest %s does not support seeding.", hash);
        }
    }
    if (key)
    {
        switch (hash) with (Hash) {
        case blake2s256: (cast(BLAKE2s256Digest)digest).key(key); break;
        case blake2b512: (cast(BLAKE2b512Digest)digest).key(key); break;
        default: 
            logError(ENOKEY, "Digest %s does not support keying.", hash);
        }
    }
    return digest;
}

__gshared HasherOptions temporary_hack;
// This function is called per-thread to initiate hash
immutable(void)* initThreadDigest()
{
    with (temporary_hack)
    return cast(immutable(void)*)newDigest(hash, seed, key);
}

//
// 
//

ubyte[] hashFile(Digest digest, string path, size_t buffersize)
{
    version (Trace) trace("path=%s", path);

    try
    {
        // BUG: LDC crashes on opAssign
        File file;
        file.open(path, "rb");
        return hashFile(digest, file, buffersize);
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
        return null;
    }
}

// NOTE: file can be a stream!
ubyte[] hashFile(Digest digest, ref File file, size_t buffersize)
{
    try
    {
        digest.reset();
        
        foreach (ubyte[] chunk; file.byChunk(buffersize))
            digest.put(chunk);
        return digest.finish();
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
        return null;
    }
}

// NOTE: This is called from another thread
void mtDirEntry(DirEntry entry, immutable(void)* uobj)//, size_t buffersize, Hash hash, Style style)
{
    string path = fixpath( entry.name );
    
    if (entry.isDir())
    {
        logWarn("'%s' is a directory", path);
        return;
    }
    
    version (Trace) trace("path=%s", path);
    
    try
    {
        Digest digest = cast(Digest)uobj; // Get thread-assigned instance
        digest.reset();
        with (temporary_hack)
        printHash(hashFile(digest, path, temporary_hack.buffersize), path, hash, style);
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
    }
}

//
// Mode: Check list
//

//TODO: Could separate file read and line splitter to introduce tests?
int processList(string path, bool autodetect, Style style, bool showstats, Hash hash, uint seed, ubyte[] key, size_t buffersize)
{
    version (Trace) trace("list=%s", path);
    
    final switch (style) with (Style) {
    case gnu: break;
    case bsd: break;
    case sri:
        logError(ENOSTYLE, "SRI hash format is not supported in file checks");
        break;
    case plain:
        logError(ENOSTYLE, "Plain hash format is not supported in file checks");
        break;
    }

    try
    {
        // Autodetect: Guess digest used in filename
        if (autodetect)
            hash = guessHash(path);
        
        // Error out if no digest was selected or guessed
        if (hash == Hash.none)
            logError(ENOHASH, autodetect ? "No hashes detected" : "No hashes selected");
        
        // Read the entire text file into memory
        scope string text = readText(path);
        if (text.length == 0)
        {
            logWarn("%s: List is empty", path);
            return ENOLIST;
        }

        string entryFile, entryHash, entryTag, lastTag;

        // Check every hash entry!
        uint statmismatch, staterror, stattotal;
        uint currline;  /// Current line
        scope digest = newDigest(hash, seed, key);
        foreach (string line; lineSplitter(text))
        {
            ++currline;

            // If line empty or starts with a comment
            if (line.length == 0 || line[0] == '#')
                continue;

            // Autodetect: Guess the line format
            if (autodetect)
            {
                if (readBSDLine(line, entryTag, entryFile, entryHash))
                    style = Style.bsd;
                else if (readGNULine(line, entryHash, entryFile))
                    style = Style.gnu;
                else
                {
                    logWarn("Unknown hash style format at line %u", currline);
                    continue;
                }
            }

            switch (style) with (Style) {
            case gnu:
                if (readGNULine(line, entryHash, entryFile) == false)
                {
                    ++staterror;
                    logWarn("Could not read GNU tag at line %u", currline);
                    continue;
                }
                break;
            case bsd:
                if (readBSDLine(line, entryTag, entryFile, entryHash) == false)
                {
                    ++staterror;
                    logWarn("Could not read BSD tag at line %u", currline);
                    continue;
                }
 
                // Check if tag name change since the last entry
                if (entryTag == lastTag)
                    break;
                
                // Find new hash type from new tag name
                Hash newhash = hashFromTag(entryTag);
                if (newhash == Hash.none)
                {
                    logWarn("Unknown tag '%s' at line %u", entryTag, currline);
                    continue;
                }
                
                // Worked out, save it and re-init digest
                lastTag = entryTag;
                digest = newDigest(newhash, seed, key);
                continue;
            default:
                assert(0);
            }

            ++stattotal;
            
            // Hash file entry
            ubyte[] hashResult = hashFile(digest, entryFile, buffersize); // Warns on error
            if (hashResult == null)
            {
                ++staterror;
                continue;
            }

            // Parse entry hash to byte array
            ubyte[] hashExpected = parseHex(entryHash);

            // Compare binary hashes.
            // secureEqual is used in case this is used server-side.
            if (secureEqual(hashResult, hashExpected) == false)
            {
                ++statmismatch;
                stderr.writeln(entryFile, ": FAILED");
                continue;
            }

            writeln(entryFile, ": OK");
        }
        
        if (showstats)
            writeln(stattotal, " total: ", statmismatch, " mismatch, ", staterror, " error");
    }
    catch (Exception ex)
    {
        logError(EINTERNAL, ex.msg);
    }

    return 0;
}

//
// Mode: against hash
//

void processAgainstEntry(DirEntry entry, immutable(void)* uobj)//, ubyte[] against, size_t buffersize)
{
    string path = fixpath( entry.name );
    
    if (entry.isDir())
    {
        logWarn("'%s' is a directory", path);
        return;
    }
    
    version (Trace) trace("path=%s", path);
    
    try
    {
        Digest digest = cast(Digest)uobj; // Get thread-assigned instance
        digest.reset();
        ubyte[] hash2 = hashFile(digest, entry, temporary_hack.buffersize);
        if (secureEqual(temporary_hack.against, hash2) == false)
        {
            logWarn("Entry '%s' is different", path);
        }
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
    }
}

//
// Mode: Compare
//

/// Compare all file entries against each other.
/// BigO: O(n * log(n)) (according to friend)
/// Params:
///   digest = Digest instance.
///   entries = List of entries.
/// Returns: Error code.
void processCompare(Digest digest, string[] entries, size_t buffersize)
{
    const size_t size = entries.length;
    
    //TODO: Support patterns

    if (size < 2)
        logError(ENOCMP, "Comparison needs 2 or more files");

    // TODO: Pre-allocate digest buffers

    // Hash all entries eagerly
    immutable(ubyte)[][] hashes = new immutable(ubyte)[][size];
    foreach (index, entry; entries)
    {
        ubyte[] fhash = hashFile(digest, entries[index], buffersize);
        if (fhash is null)
            continue;

        hashes[index] = fhash.idup;
    }
    
    static bool cmp(immutable(ubyte)[] a, immutable(ubyte)[] b)
    {
        return secureEqual(a, b);
    }

    int mismatch = compareList(hashes, &cmp,
        (immutable(ubyte)[][] items, size_t i1, size_t i2) {
            writeln("DIFFERENT: '", entries[i1], "' and '", entries[i2], "'");
        });

    if (mismatch == 0)
        writefln("All entries identical; No mismatch found.");

    exit(0);
}

//
// Mode: Benchmark
//

void benchDigest(Hash hash, ubyte[] buffer, uint seed, ubyte[] key)
{
    scope digest = newDigest(hash, seed, key);
    
    StopWatch sw;
    
    sw.start();
    digest.put(buffer);
    digest.finish();
    sw.stop();
    
    writefln("%20s: %13.4f MiB/s",
		hash.getFullName(),
		getMiBPerSecond(buffer.length, sw.peek()));
}

//
// Command-line interface
//

// print a line with spaces for field and value
void printversion(string field, string line)
{
    writefln("%*s %s", -12, field ? field : "", line);
}

void main(string[] args)
{
    enum SECRETS = 2;   /// Program secret option switches
    enum ALIASES = 26;  /// Hash aliases
    
    //TODO: Option for file basenames/fullnames? (printing)
    //TODO: -z|--zero for terminating line with null instead of newline
    HasherOptions options;
    bool ohashlist;
    Mode mode;
    GetoptResult gres = void;
    try
    {
        gres = getopt(args, config.caseSensitive,
        "cofe",         "",             { writeln(PAGE_COFE); exit(0); },
        "coffee",       "",             { writeln(PAGE_COFE); exit(0); },
        // Hash selection (delegate-based to avoid extra string comparisons)
        "crc32",        "CRC-32",       { options.hash = Hash.crc32; },
        "crc64iso",     "CRC-64-ISO",   { options.hash = Hash.crc64iso; },
        "crc64ecma",    "CRC-64-ECMA",  { options.hash = Hash.crc64ecma; },
        "murmur3a",     "MurMurHash3-32",       { options.hash = Hash.murmurhash3_32; },
        "murmur3c",     "MurmurHash3-128/32",   { options.hash = Hash.murmurhash3_128_32; },
        "murmur3f",     "MurmurHash3-128/64",   { options.hash = Hash.murmurhash3_128_64; },
        "md5",          "MD-5",         { options.hash = Hash.md5; },
        "ripemd160",    "RIPEMD-160",   { options.hash = Hash.ripemd160; },
        "rmd160",       "Alias for ripemd160",  { options.hash = Hash.ripemd160; },
        "sha1",         "SHA-1",        { options.hash = Hash.sha1; },
        "sha224",       "SHA-224",      { options.hash = Hash.sha224; },
        "sha256",       "SHA-256",      { options.hash = Hash.sha256; },
        "sha384",       "SHA-384",      { options.hash = Hash.sha384; },
        "sha512",       "SHA-512",      { options.hash = Hash.sha512; },
        "sha512-224",   "SHA-512/224",  { options.hash = Hash.sha512_224; },
        "sha512-256",   "SHA-512/256",  { options.hash = Hash.sha512_256; },
        "sha3-224",     "SHA-3-224",    { options.hash = Hash.sha3_224; },
        "sha3-256",     "SHA-3-256",    { options.hash = Hash.sha3_256; },
        "sha3-384",     "SHA-3-384",    { options.hash = Hash.sha3_384; },
        "sha3-512",     "SHA-3-512",    { options.hash = Hash.sha3_512; },
        "sha3",         "Alias for sha3-256",    { options.hash = Hash.sha3_256; },
        "shake128",     "SHAKE-128",    { options.hash = Hash.shake128; },
        "shake256",     "SHAKE-256",    { options.hash = Hash.shake256; },
        "blake2s256",   "BLAKE2s-256",  { options.hash = Hash.blake2s256; },
        "blake2b512",   "BLAKE2b-512",  { options.hash = Hash.blake2b512; },
        "b2",           "Alias for BLAKE2b-512",  { options.hash = Hash.blake2b512; },
        // Input options
        "args",         "Use entries as input text data (UTF-8)", { mode = Mode.text; },
        "A|against",    "Compare hash against file/directory entries",
            (string _, string value) {
                mode = Mode.against;
                options.against = parseHex(value);
            },
        "against-sri",  "Compare SRI against file/directory entries",
            (string _, string value) {
                mode = Mode.against;
                
                // Try SRI format
                string t, h;
                if (readSRILine(value, t, h)) // Try HASH-B64DIGEST format
                {
                    Hash hash = guessHash(t);
                    if (hash != Hash.none)   // otherwise, leave it at none
                        options.hash = hash; // another check is performed later
                    
                     options.against = parseBase64(h);
                }
                else // Try base64 digest only
                {
                     options.against = parseBase64(value);
                }
            },
        "B|buffersize", "Set buffer size, affects file/mmfile/stdin (Default=1M)",
            (string _, string usize) { options.buffersize = cast(size_t)usize.toBinaryNumber(); },
        "j|parallel",   "Spawn n threads for pattern entries, 0 for all (Default=1)", &options.threads,
        // Check file options
        "c|check",      "List: Check hash list from file",
            { mode = Mode.list; },
        "a|autocheck",  "List: Check hash list from file automatically",
            { mode = Mode.list; options.autodetect = true; },
        "hidestats",    "List: Hide end statistics", &options.hidestats,
        // Path options
        "r|depth",      "Depth: Traverse deepest sub-directories first",
            { options.span = SpanMode.depth; },
        "breath",       "Depth: Traverse immediate sub-directories first",
            { options.span = SpanMode.breadth; },
        "nofollow",     "Links: Do not follow symbolic links", &options.nofollow,
        // Hash formatting
        "tag",          "Create BSD-style hashes", { options.style = Style.bsd; },
        "sri",          "Create SRI-style hashes", { options.style = Style.sri; },
        "plain",        "Create plain hashes",     { options.style = Style.plain; },
        // Hash parameters
        "key",          "Binary key file for BLAKE2 hashes",
            (string _, string upath) { options.key = cast(ubyte[])readAll(upath); },
        "seed",         "Seed literal argument for Murmurhash3 hashes",
            (string _, string useed) { options.seed = cparse(useed); },
        // Special modes
        "C|compare",    "Compares all file entries", { mode = Mode.compare; },
        "benchmark",    "Run benchmarks on all supported hashes", &options.benchmark,
        // Pages
        "H|hashes",     "List supported hashes", &ohashlist,
        "version",      "Show version page and quit",
            {
                printversion("ddgst", APPVERSION);
                printversion(null, "Built: "~__TIMESTAMP__);
                printversion("License", "CC0-1.0 Universal");
                printversion(null, "No rights reserved");
                printversion("Homepage", "<https://github.com/dd86k/ddgst>");
                printversion("Compiler", D_COMPILER);
                printversion("sha3-d", SHA3D_VERSION_STRING);
                printversion("blake2-d", BLAKE2D_VERSION_STRING);
                exit(0);
            },
        "ver",          "Show version and quit",        { writeln(APPVERSION); exit(0); },
        "license",      "Show license page and quit",   { writeln(PAGE_LICENSE); exit(0); },
        );
    }
    catch (Exception ex)
    {
        logError(ECLI, ex.msg);
    }

    // -h|--help: Show help page
    if (gres.helpWanted)
    {
    Lhelp:
        writeln(PAGE_HELP);
        foreach (ref Option opt; gres.options[ALIASES + SECRETS..$])
        {
            with (opt)
            if (optShort)
                writefln("  %s, %-12s  %s", optShort, optLong, help);
            else
                writefln("      %-12s  %s", optLong, help);
        }
        writeln("\nThis program has actual coffee-making abilities.");
        exit(0);
    }
    
    // -H|--hashes: Show hash list
    if (ohashlist)
    {
        writeln("Hashes available:");
        foreach (ref Option opt; gres.options[SECRETS..SECRETS+ALIASES])
        {
            with (opt) writefln("  %-12s  %s", optLong, help);
        }
        exit(0);
    }
    
    // Benchmark mode requires no arguments
    // Having it here allows buffer arg to be set after this argument
    if (options.benchmark)
    {
        ubyte[] buffer = new ubyte[options.buffersize];
        writeln("* buffer size: ", buffer.length.toStringBinary());
        foreach (Hash ht; EnumMembers!Hash[1..$]) // Skip 'none'
            benchDigest(ht, buffer, options.seed, options.key);
        exit(0);
    }
    
    // From this point, a hash must be selected
    
    // Get argument entries
    string[] entries = args[1..$];
    
    // If there are no entries and no hash, bring up the help page!
    if (entries.length == 0 && options.hash == Hash.none)
        goto Lhelp;
    
    // Hash selected, no entries, stdin sub-mode
    if (entries.length == 0)
    {
    Lstdin:
        printHash(
            hashFile(
                newDigest(options.hash, options.seed, options.key),
            stdin, options.buffersize),
        "-", options.hash, options.style);
        return;
    }
    
    // Temporary hack until MT implementation improves
    temporary_hack = options;
    
    Digest digest;
    final switch (mode) {
    case Mode.file: // Default
        if (options.hash == Hash.none)
            logError(ENOHASH, "No hashes selected");
        
        foreach (string entry; entries)
        {
            // TODO: Should return here to process entries after "-"
            if (entry == "-")
                goto Lstdin;
            
            // If a pattern character is detected (es. on Windows),
            // it's a glob pattern for dirEntries.
            // e.g., "../*.d"
            if (isPattern(entry))
            {
                try
                {
                    scope folder  = dirName(entry);  // Results to "." by default
                    scope pattern = baseName(entry); // Extract pattern
                    version (Trace) trace("folder=%s pattern=%s", folder, pattern);
                    dirEntriesMT(folder, pattern, options.span, !options.nofollow,
                        &initThreadDigest, &mtDirEntry, options.threads);
                }
                catch (Exception ex)
                {
                    logError(EINTERNAL, ex.msg);
                }
                continue;
            }
            
            // Or else, treat entry as a single file, that must exist
            if (exists(entry) == false)
            {
                logWarn("Entry '%s' does not exist", entry);
                continue;
            }
            
            // Attemped to treat patterns and folders the same, but
            // none of the *sum utils do it anyway.
            if (isDir(entry))
            {
                logWarn("Entry '%s' is a directory", entry);
                continue;
            }
            
            // Here since pattern might be used
            if (digest is null) digest = newDigest(options.hash, options.seed, options.key);
            
            printHash(hashFile(digest, entry, options.buffersize), entry, options.hash, options.style);
        }
        return;
    case Mode.list:
        foreach (string entry; entries)
        {
            with (options)
            cast(void)processList(entry, autodetect, style, !hidestats, hash, seed, key, buffersize);
        }
        return;
    case Mode.against:
        if (options.hash == Hash.none)
            logError(ENOHASH, "No hashes selected");
        if (options.against == null)
            logError(EINTERNAL, "Missing digest to compare with");
        
        // If a checksum was selected, "normalize" it.
        // This is due to how sums work as integers and on little-endian plaforms
        // the hex number ordering is inversed.
version (LittleEndian)
{
        switch (options.hash) {
        case Hash.crc32:
            if (options.against.length < uint.sizeof)
                logError(EINTERNAL, "Not enough bytes for comparison");
            
            uint *u32p = cast(uint*)options.against.ptr;
            *u32p = bswap(*u32p);
            break;
        case Hash.crc64ecma, Hash.crc64iso:
            if (options.against.length < ulong.sizeof)
                logError(EINTERNAL, "Not enough bytes for comparison");
            
            ulong *u64p = cast(ulong*)options.against.ptr;
            *u64p = bswap(*u64p);
            break;
        default:
        }
}
        
        foreach (string entry; entries)
        {
            if (isPattern(entry))
            {
                try
                {
                    temporary_hack = options;
                    
                    scope pattern = baseName(entry); // Extract pattern
                    scope folder  = dirName(entry);  // Results to "." by default
                    dirEntriesMT(folder, pattern, options.span, !options.nofollow,
                        &initThreadDigest, &processAgainstEntry, options.threads);
                }
                catch (Exception ex)
                {
                    logError(EINTERNAL, ex.msg);
                }
                continue;
            }
            
            if (exists(entry) == false)
            {
                logWarn("Entry '%s' does not exist", entry);
                continue;
            }
            if (isDir(entry))
            {
                logWarn("Entry '%s' is a directory", entry);
                continue;
            }
            
            // Here since pattern might have been used
            if (digest is null) digest = newDigest(options.hash, options.seed, options.key);
            
            ubyte[] hash2 = hashFile(digest, entry, options.buffersize);
            if (secureEqual(options.against, hash2) == false)
            {
                logWarn("Entry '%s' is different", entry);
            }
        }
        return;
    case Mode.compare:
        //TODO: Consider choosing a default for this mode
        if (options.hash == Hash.none)
            logError(ENOHASH, "No hashes selected");
        
        processCompare(newDigest(options.hash, options.seed, options.key), entries, options.buffersize);
        return;
    case Mode.text:
        if (options.hash == Hash.none)
            logError(ENOHASH, "No hashes selected");
        
        digest = newDigest(options.hash, options.seed, options.key);
        foreach (string entry; entries)
        {
            digest.put(cast(ubyte[])entry);
        }
        printHash(digest.finish(), text(`"`, entries.join(), `"`), options.hash, options.style);
        return;
    }
}
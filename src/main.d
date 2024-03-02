/// Command-line interface.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module main;

import std.array : join;
import std.conv : text;
import std.datetime.stopwatch;
import std.digest : secureEqual;
import std.file;
import std.format : format;
import std.getopt;
import std.stdio;
import std.process;
import std.traits : EnumMembers;
import std.path : baseName, dirName;
import core.stdc.stdlib : exit;
import hasher;
import mtdir;
import utils;

// NOTE: secureEqual usage
//       In the case where someone is using this utility on a server,
//       it's simply better being safe than sorry. At the same time,
//       if that were the case, what the hell?

//TODO: Messages to avoid copy-paste
//      Could have functions like (e.g.) ensureIsDir that would return true if
//      entry is a directory, and prints a warning.

enum APPVERSION = "3.0.0";

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
    // Leave GC enabled, but avoid cleanup on exit
    extern (C) __gshared string[] rt_options = [ "cleanup:none" ];
}

alias readAll = std.file.read;

immutable string PAGE_VERSION =
`ddh ` ~ APPVERSION ~ BUILD_TYPE ~ ` (built: ` ~ __TIMESTAMP__ ~ `)
Using sha3-d ` ~ SHA3D_VERSION_STRING ~ `, blake2-d ` ~ BLAKE2D_VERSION_STRING ~ `
No rights reserved
License: CC0
Homepage: <https://github.com/dd86k/ddh>
Compiler: ` ~ __VENDOR__ ~ format(" v%u.%03u", __VERSION__ / 1000, __VERSION__ % 1000);

immutable string PAGE_HELP =
`Usage:
  ddh [options...] [files...|--stdin]
  ddh [options...] --autocheck file
  ddh {--ver|--version|--help|--license}

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
    .......
   _|     |
  / |     |
  \_|     |
    `-----´
SECRET";

struct HasherOptions
{
    Hash hash;
    Tag tag;
    Digest digest;
    size_t bufferSize = 4096;
    uint seed;
    ubyte[] key;
    SpanMode span;
    ubyte[] against;
}
__gshared HasherOptions options;

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

void logError(string mod = __FUNCTION__, int line = __LINE__, A...)(int code, string fmt, A args)
{
    stderr.writef("error: (code %d) ", code);
    debug stderr.write("[", mod, ":", line, "] ");
    stderr.writefln(fmt, args);
    exit(code);
}

Digest newDigest(Hash hash)
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
    //TODO: Fix ugly global hack
    if (options.seed)
    {
        switch (hash) with (Hash) {
        case murmurhash3_32:     (cast(MurmurHash3_32_SeededDigest)digest).seed(options.seed); break;
        case murmurhash3_128_32: (cast(MurmurHash3_128_32_SeededDigest)digest).seed(options.seed); break;
        case murmurhash3_128_64: (cast(MurmurHash3_128_64_SeededDigest)digest).seed(options.seed); break;
        default: throw new Exception(
            text("Digest ", options.hash, " does not support seeding."));
        }
    }
    if (options.key)
    {
        switch (hash) with (Hash) {
        case blake2s256: (cast(BLAKE2s256Digest)digest).key(options.key); break;
        case blake2b512: (cast(BLAKE2b512Digest)digest).key(options.key); break;
        default: throw new Exception(
            text("Digest ", options.hash, " does not support keying."));
        }
    }
    return digest;
}

ubyte[] hashFile(Digest digest, string path)
{
    version (Trace) trace("path=%s", path);

    try
    {
        // BUG: LDC crashes on opAssign
        File file;
        file.open(path, "rb");
        scope(exit) file.close();
        return hashFile(digest, file);
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
        return null;
    }
}

// NOTE: file can be a stream!
ubyte[] hashFile(Digest digest, ref File file)
{
    version (Trace) trace("path=%s", path);

    try
    {
        foreach (ubyte[] chunk; file.byChunk(options.bufferSize))
            digest.put(chunk);
        return digest.finish();
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
        return null;
    }
}

// This function is called per-thread to initiate hash
immutable(void)* initThreadDigest()
{
    return cast(immutable(void)*)newDigest(options.hash);
}

// NOTE: This is called from another thread
void processDirEntry(DirEntry entry, immutable(void)* uobj)
{
    string path = entry.name[2..$];
    
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
        printHash(hashFile(digest, entry.name), path);
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
    }
}

void processAgainstEntry(DirEntry entry, immutable(void)* uobj)
{
    string path = entry.name[2..$];
    
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
        ubyte[] hash2 = hashFile(digest, entry);
        if (secureEqual(options.against, hash2) == false)
        {
            logWarn("Entry '%s' is different", path);
        }
    }
    catch (Exception ex)
    {
        logWarn(ex.msg);
    }
}

void printHash(ubyte[] result, string filename)
{
    if (result == null)
        return;
    
    final switch (options.tag) with (Tag) {
    case gnu: // hash  file
        writeln(formatHashHex(options.hash, result), "  ", filename);
        break;
    case bsd: // TAG(file)= hash
        writeln(getBSDName(options.hash), "(", filename, ")= ", formatHashHex(options.hash, result));
        break;
    case sri: // type-hash
        writeln(getAliasName(options.hash), '-', formatHashBase64(options.hash, result));
        break;
    case plain: // hash
        writeln(formatHashHex(options.hash, result));
        break;
    }
}

//
// Command-line interface
//

void cliBenchmark()
{
    ubyte[] buffer = new ubyte[options.bufferSize];
    
    writeln("* buffer size: ", buffer.length.toStringBinary());
    
    foreach (Hash ht; EnumMembers!Hash[1..$]) // Skip 'none'
    {
        benchDigest(ht, buffer);
    }
    
    exit(0);
}

void benchDigest(Hash hash, ubyte[] buffer)
{
    scope digest = newDigest(hash);
    
    StopWatch sw;
    
    sw.start();
    digest.put(buffer);
    digest.finish();
    sw.stop();
    
    writefln("%20s: %13.4f MiB/s",
		hash.getFullName(),
		getMiBPerSecond(buffer.length, sw.peek()));
}

void main(string[] args)
{
    //TODO: Option for file basenames/fullnames? (printing)
    //TODO: Consider "building" options from stack to heap?
    //TODO: -z|--zero for terminating line with null instead of newline
    bool ocompare;
    bool ohashes;
    bool onofollow;
    bool ostdin;
    bool oautodetect;
    int othreads = 1;
    string arg;
    Mode mode;
    GetoptResult gres = void;
    try
    {
        gres = getopt(args, config.caseSensitive,
        "cofe",         "",             { writeln(PAGE_COFE); exit(0); },
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
        "shake128",     "SHAKE-128",    { options.hash = Hash.shake128; },
        "shake256",     "SHAKE-256",    { options.hash = Hash.shake256; },
        "blake2s256",   "BLAKE2s-256",  { options.hash = Hash.blake2s256; },
        "blake2b512",   "BLAKE2b-512",  { options.hash = Hash.blake2b512; },
        // Input options
        "arg",          "Input: Argument is input data as UTF-8 text", { mode = Mode.text; },
        "stdin",        "Input: Standard input (stdin)", &ostdin,
        "A|against",    "Compare file against string hash",
            (string _, string uhash) { mode = Mode.against; options.against = unformatHex(uhash); },
        "B|buffersize", "Set buffer size, affects file/mmfile/stdin (Default=4K)",
            (string _, string usize) { options.bufferSize = usize.toBinaryNumber(); },
        "j|parallel",   "Spawn threads for glob pattern entries, 0 for all threads (Default=1)", &othreads,
        // Check file options
        "c|check",      "Check hashes list in this file", { mode = Mode.list; },
        "a|autocheck",  "Automatically determine hash type and process list",
            { mode = Mode.list; oautodetect = true; },
        // Path options
        "r|depth",      "Depth: Deepest directories first", { options.span = SpanMode.depth; },
        "breath",       "Depth: Sub directories first",     { options.span = SpanMode.breadth; },
        "shallow",      "Depth: Same directory (default)",  { options.span = SpanMode.shallow; },
        "nofollow",     "Links: Do not follow symbolic links", &onofollow,
        // Hash formatting
        "tag",          "Create BSD-style hashes", { options.tag = Tag.bsd; },
        "sri",          "Create SRI-style hashes", { options.tag = Tag.sri; },
        "plain",        "Create plain hashes",     { options.tag = Tag.plain; },
        // Hash parameters
        "key",          "Binary key file for BLAKE2 hashes",
            (string _, string upath) { options.key = cast(ubyte[])readAll(upath); },
        "seed",         "Seed literal argument for Murmurhash3 hashes",
            (string _, string useed) { options.seed = cparse(useed); },
        // Special modes
        "C|compare",    "Compares all file entries", &ocompare,
        "benchmark",    "Etc: Run benchmarks", &cliBenchmark,
        // Pages
        "H|hashes",     "List supported hashes", &ohashes,
        "version",      "Show version page and quit",   { writeln(PAGE_VERSION); exit(0); },
        "ver",          "Show version and quit",        { writeln(APPVERSION); exit(0); },
        "license",      "Show license page and quit",   { writeln(PAGE_LICENSE); exit(0); },
        );
    }
    catch (Exception ex)
    {
        logError(1, ex.msg);
    }

    enum SECRETS = 1;
    enum ALIASES = 24;

    // -h|--help: Show help page
    if (gres.helpWanted)
    {
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
    if (ohashes)
    {
        writeln("Hashes available:");
        foreach (ref Option opt; gres.options[SECRETS..SECRETS+ALIASES])
        {
            with (opt) writefln("  %-12s  %s", optLong, help);
        }
        exit(0);
    }
    
    string[] entries = args[1..$];
    
    //TODO: make function ensureHashSelected()
    //      exists if no hash selected
    
    // No entries or stdin option
    if (entries.length == 0 || ostdin)
    {
        if (options.hash == Hash.none)
            logError(2, "No hashes selected");
        printHash(hashFile(newDigest(options.hash), stdin), "-");
    }
    
    //TODO: Might need to have a multithread stack-based hasher.
    //      Each entry aren't being multithreaded (unless std.parallelism.parallel)
    //      is used, but needs to be applied to the other modes (list, compare, etc.).
    //      Stack could have "file" and "dir" entries (to expand later with dirEntries).
    //TODO: Do a function with callback/delegate for mode behavior?
    //TODO: Cache per-thread instance when pattern is used again?
    Digest digest;
    final switch (mode) {
    case Mode.file: // Default
        if (options.hash == Hash.none)
            logError(2, "No hashes selected");
        
        foreach (string entry; entries)
        {
            // If a pattern character is detected (es. on Windows),
            // it's a glob pattern for dirEntries.
            // e.g., "../*.d"
            if (isPattern(entry))
            {
                try
                {
                    scope pattern = baseName(entry); // Extract pattern
                    scope folder  = dirName(entry);  // Results to "." by default
                    dirEntriesMT(folder, pattern, options.span, !onofollow,
                        &initThreadDigest, &processDirEntry, othreads);
                }
                catch (Exception ex)
                {
                    logError(2, ex.msg);
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
            if (digest is null) digest = newDigest(options.hash);
            
            printHash(hashFile(digest, entry), entry);
        }
        return;
    case Mode.list:
        //if (oautocheck)
        //    exit(cliAutoCheck(entries));
        //if (options.hash == Hash.none)
        //    logError(2, "No hashes selected");
        logError(20, "Not implemented");
        return;
    case Mode.against:
        if (options.hash == Hash.none)
            logError(2, "No hashes selected");
        
        foreach (string entry; entries)
        {
            if (isPattern(entry))
            {
                try
                {
                    scope pattern = baseName(entry); // Extract pattern
                    scope folder  = dirName(entry);  // Results to "." by default
                    dirEntriesMT(folder, pattern, options.span, !onofollow,
                        &initThreadDigest, &processAgainstEntry, othreads);
                }
                catch (Exception ex)
                {
                    logError(2, ex.msg);
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
            
            // Here since pattern might be used
            if (digest is null) digest = newDigest(options.hash);
            
            ubyte[] hash2 = hashFile(digest, entry);
            if (secureEqual(options.against, hash2) == false)
            {
                logWarn("Entry '%s' is different", entry);
            }
        }
        return;
    case Mode.compare:
        //TODO: Consider choosing a default for this mode
        //if (options.hash == Hash.none)
        //    logError(2, "No hashes selected");
        logError(20, "Not implemented");
        return;
    case Mode.text:
        digest = newDigest(options.hash);
        foreach (string entry; entries)
        {
            digest.put(cast(ubyte[])entry);
        }
        printHash(digest.finish(), text(`"`, entries.join(" "), `"`));
        return;
    }
}
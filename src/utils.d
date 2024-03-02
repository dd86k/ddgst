/// Smaller utilities.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module utils;

import std.conv : text;
import std.format.read : formattedRead;
import std.string : toStringz;
import std.digest : secureEqual;
import std.uni : asLowerCase;
import std.datetime : Duration, dur;
import core.stdc.stdio : sscanf;
import core.stdc.ctype : toupper;

/// Parse string into a 32-bit unsigned integer.
/// Params: input = 
/// Returns: Unformatted number.
uint cparse(string input)
{
    int u = void;
    if (sscanf(input.toStringz, "%i", &u) != 1)
        throw new Exception("Could not parse input");
    return cast(uint)u;
}

private enum
{
    K = 1024L,
    M = K * 1024L,
    G = M * 1024L,
    T = G * 1024L,
}

/// Unformat a string containing a binary size to bytes.
/// Throws: Exception on error.
/// Params: n = String input.
/// Returns: Size in bytes.
ulong toBinaryNumber(string n)
{
    ulong u = void;
    char suffix;
    if (n.formattedRead!"%d%c"(u, suffix) < 1)
        throw new Exception("Could not read binary number");
    
    if (u == 0)
        return 0;
    if (suffix == char.init)
        suffix = 'B';
    
    switch (toupper(suffix)) {
    case 'T': u *= T; break;
    case 'G': u *= G; break;
    case 'M': u *= M; break;
    case 'K': u *= K; break;
    case 'B': break;
    default:
        throw new Exception("Unsupported suffix");
    }
    
    version (LP32)
    {
        enum LIMIT = 2 * G; /// Buffer read limit
        if (u > LIMIT)
            throw new Exception("Buffer exceeds limit of 2 GiB");
    }
    
    return u;
}
unittest
{
    assert(toBinaryNumber("0") == 0);
    assert(toBinaryNumber("1") == 1);
    assert(toBinaryNumber("1K")  == 1 * K);
    assert(toBinaryNumber("2K")  == 2 * K);
    assert(toBinaryNumber("32K") == 32 * K);
    assert(toBinaryNumber("1024KB")  == 1 * M);
    assert(toBinaryNumber("2048KiB") == 2 * M);
    assert(toBinaryNumber("1M") == 1 * M);
    assert(toBinaryNumber("1G") == 1 * G);
    assert(toBinaryNumber("2G") == 2 * G);
    assert(toBinaryNumber("3g") == 3 * G);
    assert(toBinaryNumber("1T") == 1 * T);
}

string toStringBinary(ulong n)
{
    string suffix = void;
    if (n >= T)
    {
        n /= T;
        suffix = "TiB";
    }
    else if (n >= G)
    {
        n /= G;
        suffix = "GiB";
    }
    else if (n >= M)
    {
        n /= M;
        suffix = "MiB";
    }
    else if (n >= K)
    {
        n /= K;
        suffix = "KiB";
    }
    else
    {
        suffix = "Bytes";
    }
    return text(n, ' ', suffix);
}
unittest
{
    assert(2.toStringBinary()       == "2 Bytes");
    assert((2 * M).toStringBinary() == "2 MiB");
}

/// Convert a Duration to a total number of seconds as a floating-point number.
/// Note: This is internally converted to µseconds.
/// Params: duration = Duration, typically from a StopWatch.
/// Returns: Total seconds with remainder.
double toFloatSeconds(Duration duration) pure
{
    // Example: 1,234,567,000 ns / 1,000,000,000 ns -> ~1.234 s
    // NOTE: Can't do Duration / dur!"seconds"(1) that easily.
    //       Due to integer division, since internal is ulong.
	return cast(double)duration.total!"nsecs" / 1_000_000_000.0;
}
unittest
{
    import std.math : isClose;
    import std.stdio;
    
    assert(dur!"seconds"(1).toFloatSeconds == 1.0);
    assert(dur!"seconds"(2).toFloatSeconds == 2.0);
    assert(dur!"msecs"(1000).toFloatSeconds == 1.0);
    assert(dur!"msecs"( 500).toFloatSeconds == 0.5);
    assert(dur!"msecs"(1500).toFloatSeconds == 1.5);
}

/// Get processing speed as MiB/s with a given total size and duration.
/// Params:
///   size = Sample or buffer size.
///   duration = Total duration of 
double getMiBPerSecond(ulong size, Duration duration) pure
{
    return (cast(double)size / M) / duration.toFloatSeconds;
}
unittest
{
    // Taking 2 seconds for 2 megabytes: 1 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(2)) == 1.0);
    // Taking 1 second  for 2 megabytes: 2 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(1)) == 2.0);
}

import std.file;
import std.path : baseName, buildPath;

/// Used with dirEntries, confirms if entry is a glob pattern.
/// Note: On POSIX systems, shells tend to expend entries themselves.
/// Params: entry = Path entry.
/// Returns: True if glob pattern.
bool isPattern(string entry)
{
    // NOTE: This is faster than checking folders (I/O related)
    foreach (char c; entry)
    {
        switch (c){
        case '*':       // Match zero or more characters
        case '?':       // Match one character
        case '[', ']':  // Match characters
        case '{', '}':  // Match strings
            return true;
        default:
            continue;
        }
    }
    
    return false;
}
unittest
{
    // Existing examples
    assert(isPattern("*"));
    assert(isPattern("*.*"));
    assert(isPattern("f*b*r"));
    assert(isPattern("f???bar"));
    assert(isPattern("[fg]???bar"));
    assert(isPattern("[!gh]*bar"));
    assert(isPattern("bar.{foo,bif}z"));
    // Should only be files or folders themselves
    assert(isPattern(".") == false);
    assert(isPattern("file") == false);
    assert(isPattern("src/file") == false);
}

// This function won't throw due to a missing file, unlike isDir.
bool isFolder(string entry)
{
    if (exists(entry) == false)
        return false;
    
    return entry.isDir;
}
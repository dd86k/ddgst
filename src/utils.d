/// Smaller utilities.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module utils;

import std.conv : text;
import std.datetime : Duration, dur;
import std.format.read : formattedRead;
import std.string : toStringz;
import std.path : dirSeparator;
import core.stdc.stdio : sscanf;
import core.stdc.ctype : toupper;

//TODO: entryState(path)
//      Possible performance gain avoiding calling exists() and isDir()
//      Use OS functions (GetFileAttributes/GetFileType, stat_t, etc.)

/// Parse string into a 32-bit unsigned integer.
/// Params: input = String user input.
/// Returns: Unformatted number.
int cparse(string input)
{
    int u = void;
    if (sscanf(input.toStringz, "%i", &u) != 1)
        throw new Exception("Could not parse input");
    return cast(uint)u;
}
unittest
{
    import std.conv : octal;
    assert(cparse("0") == 0);
    assert(cparse("1") == 1);
    assert(cparse("010") == octal!10);
    assert(cparse("0x10") == 0x10);
    assert(cparse("0x7fffffff") == 0x7fff_ffff);
    assert(cparse("0x80000000") == 0x8000_0000);
}

private enum
{
    K = 1024L,
    M = K * 1024L,
    G = M * 1024L,
    T = G * 1024L,
}

template KiB(uint k) {
    enum KiB = k * K;
}

template MiB(uint m) {
    enum MiB = m * M;
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
double toDoubleSeconds(Duration duration) pure
{
    static immutable NSECS = dur!"seconds"(1).total!"nsecs";
    // Example: 1,234,567,000 ns / 1,000,000,000 ns -> ~1.234 s
    // NOTE: Can't do Duration / dur!"seconds"(1) that easily.
    //       Due to integer division, since internal is ulong.
	return cast(double)duration.total!"nsecs" / NSECS;
}
unittest
{
    assert(dur!"seconds"(1).toDoubleSeconds  == 1.0);
    assert(dur!"seconds"(2).toDoubleSeconds  == 2.0);
    assert(dur!"msecs"(1000).toDoubleSeconds == 1.0);
    assert(dur!"msecs"( 500).toDoubleSeconds == 0.5);
    assert(dur!"msecs"(1500).toDoubleSeconds == 1.5);
}

/// Get processing speed as MiB/s with a given total size and duration.
/// Params:
///   size = Sample or buffer size.
///   duration = Total duration of 
double getMiBPerSecond(ulong size, Duration duration) pure
{
    return (cast(double)size / M) / duration.toDoubleSeconds;
}
unittest
{
    // Taking 1 second for 1 megabyte: 1 MiB/s
    assert(getMiBPerSecond(1 * M, dur!"seconds"(1)) == 1.0);
    // Taking half a second for half a megabyte: 1 MiB/s
    assert(getMiBPerSecond(512 * K, dur!"msecs"(500)) == 1.0);
    // Taking 2 seconds for 2 megabytes: 1 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(2)) == 1.0);
    // Taking 1 second  for 2 megabytes: 2 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(1)) == 2.0);
    // Taking 2 seconds for 4 megabytes: 2 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(1)) == 2.0);
    // Taking 4 seconds for 2 megabytes: 0.5 MiB/s
    assert(getMiBPerSecond(2 * M, dur!"seconds"(4)) == 0.5);
}

/// Used with dirEntries, confirms if entry is a glob pattern.
/// Note: On POSIX systems, shells tend to expend entries themselves.
/// Params: entry = Path entry.
/// Returns: True if glob pattern.
bool isPattern(string entry)
{
    // NOTE: This is potentially faster than checking folders (I/O related)
    //       A benchmark would be nice
    foreach (char c; entry)
    {
        switch (c) {
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
    assert(isPattern(`*`));
    assert(isPattern(`*.*`));
    assert(isPattern(`f*b*r`));
    assert(isPattern(`f???bar`));
    assert(isPattern(`[fg]???bar`));
    assert(isPattern(`[!gh]*bar`));
    assert(isPattern(`bar.{foo,bif}z`));
    // Should only be files or folders themselves
    assert(isPattern(`.`) == false);
    assert(isPattern(`file`) == false);
    assert(isPattern(`src/file`) == false);
    assert(isPattern(`src\file`) == false);
}

int compareList(T)(T[] items, bool function(T,T) fcompare,
    void delegate(T[],size_t,size_t) fannounce = null)
{
    if (items.length <= 1)
        return 0;

    int mismatch;
    
    // Compare every hashes together.
    // The outer loop checks the secondary entry, traveling towards the end.
    for (size_t distance = 1; distance < items.length; ++distance)
    {
        for (size_t index; index < items.length; ++index)
        {
            size_t index2 = index + distance;

            if (index2 >= items.length)
                break;

            // Skip error entries
            if (items[index2] == T.init)
                continue;
            
            T a = items[index];
            T b = items[index2];

            if (fcompare(a, b))
                continue;

            if (fannounce) fannounce(items, index, index2);

            ++mismatch;
        }
    }
    
    return mismatch;
}
unittest
{
    import std.stdio;
    
    static bool cmp(immutable(char) a, immutable(char) b)
    {
        return a == b;
    }
    
    assert(compareList("AAA",   &cmp) == 0);
    assert(compareList("AAB",   &cmp) == 2);
    assert(compareList("AAB",   &cmp) == 2);
    assert(compareList("AAA",   &cmp) == 0);
    assert(compareList("ABC",   &cmp) == 3);
    assert(compareList("ABCD",  &cmp) == 6);
    assert(compareList("ABCDE", &cmp) == 10);
}

// dirEnties entry prefix
private immutable string pf = "."~dirSeparator;

// Fixes the annoying relative path that dirEntries *might* introduce.
// Safer than preemptively truncating it.
string fixpath(string entry)
{
    if (entry.length <= pf.length)
        return entry;
    
    return entry[0..pf.length] != pf ? entry : entry[pf.length..$];
}
unittest
{
    assert(fixpath("a") == "a");
    assert(fixpath("abc") == "abc");
    assert(fixpath(pf~"abc") == "abc");
}
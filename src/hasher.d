/// Hash maker.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module hasher;

public import std.digest;
public import std.digest.sha;
public import std.digest.md;
public import std.digest.ripemd;
public import std.digest.crc;
public import std.digest.murmurhash;
public import sha3d, blake2d;
import std.base64;
import std.string : indexOf;

// Adds dynamic seeding to supported hashes
private class HashSeeded(T) if (isDigest!T && hasBlockSize!T) : WrapperDigest!T
{
    @trusted nothrow void seed(uint input)
    {
        _digest = T(input);
    }
}

public alias MurmurHash3_32_SeededDigest = HashSeeded!(MurmurHash3!32);
public alias MurmurHash3_128_32_SeededDigest = HashSeeded!(MurmurHash3!(128, 32));
public alias MurmurHash3_128_64_SeededDigest = HashSeeded!(MurmurHash3!(128, 64));

enum Hash
{
    none,
    crc32,
    crc64iso,
    crc64ecma,
    murmurhash3_32,
    murmurhash3_128_32,
    murmurhash3_128_64,
    md5,
    ripemd160,
    sha1,
    sha224,
    sha256,
    sha384,
    sha512,
    sha512_224,
    sha512_256,
    sha3_224,
    sha3_256,
    sha3_384,
    sha3_512,
    shake128,
    shake256,
    blake2s256,
    blake2b512,
}

enum Style
{
    gnu,
    bsd,
    sri,
    plain
}

/*
                    BSD             GNU
crc32               "CRC32"
crc64iso            "CRC64ISO"
crc64ecma           "CRC64ECMA"
murmurhash3_32      "MURMUR3A"
murmurhash3_128_32  "MURMUR3C"
murmurhash3_128_64  "MURMUR3F"
md5                 "MD5"
ripemd160           "RIPEMD160"     "RMD160"
sha1                "SHA1"
sha224              "SHA2-224"      "SHA224"
sha256              "SHA2-256"      "SHA256"
sha384              "SHA2-384"      "SHA384"
sha512              "SHA2-512"      "SHA512"
sha512_224          "SHA2-512/224"
sha512_256          "SHA2-512/256"
sha3_224            "SHA3-224"
sha3_256            "SHA3-256"
sha3_384            "SHA3-384"
sha3_512            "SHA3-512"
shake128            "SHAKE-128"
shake256            "SHAKE-256"
blake2s256          "BLAKE2S-256"  "BLAKE2s"
blake2b512          "BLAKE2B-512"  "BLAKE2b"
*/
struct HashName
{
    Hash hash;
    string alias_;
    string full;
    string bsdTag; // OpenSSL uses this
    string gnuTag;
}
immutable HashName[] hashNames = [
    // NOTE: Checksum tag names are assumed
    //                          Alias         Full-digest/core      BSD             GNU
    { Hash.crc32,               "crc32",      "CRC-32",             "CRC32" },
    { Hash.crc64iso,            "crc64iso",   "CRC-64-ISO",         "CRC64ISO" },
    { Hash.crc64ecma,           "crc64ecma",  "CRC-64-ECMA",        "CRC64ECMA" },
    { Hash.murmurhash3_32,      "murmur3a",   "MurmurHash3-32",     "MURMUR3A" },
    { Hash.murmurhash3_128_32,  "murmur3c",   "MurmurHash3-128/32", "MURMUR3C" },
    { Hash.murmurhash3_128_64,  "murmur3f",   "MurmurHash3-128/64", "MURMUR3F" },
    { Hash.md5,                 "md5",        "MD-5-128",           "MD5" },
    { Hash.ripemd160,           "ripemd160",  "RIPEMD-160",         "RIPEMD160",    "RMD160" },
    { Hash.sha1,                "sha1",       "SHA-1",              "SHA1" },
    { Hash.sha224,              "sha224",     "SHA-224",            "SHA2-224",     "SHA224" },
    { Hash.sha256,              "sha256",     "SHA-256",            "SHA2-256",     "SHA256" },
    { Hash.sha384,              "sha384",     "SHA-384",            "SHA2-384",     "SHA384" },
    { Hash.sha512,              "sha512",     "SHA-512",            "SHA2-512",     "SHA512" },
    { Hash.sha512_224,          "sha512_224", "SHA-512/224",        "SHA2-512/224", },
    { Hash.sha512_256,          "sha512_256", "SHA-512/256",        "SHA2-512/256", },
    { Hash.sha3_224,            "sha3_224",   "SHA-3-224",          "SHA3-224" },
    { Hash.sha3_256,            "sha3_256",   "SHA-3-256",          "SHA3-256" },
    { Hash.sha3_384,            "sha3_384",   "SHA-3-384",          "SHA3-384" },
    { Hash.sha3_512,            "sha3_512",   "SHA-3-512",          "SHA3-512" },
    { Hash.shake128,            "shake128",   "SHAKE-128" },
    { Hash.shake256,            "shake256",   "SHAKE-256" },
    { Hash.blake2s256,          "blake2s256", "BLAKE2s-256",        "BLAKE2S-256", "BLAKE2s" },
    { Hash.blake2b512,          "blake2b512", "BLAKE2b-512",        "BLAKE2B-512", "BLAKE2b" },
];

string getAliasName(Hash hash)
{
    size_t idx = cast(size_t)(hash - 1);
    if (idx >= hashNames.length) return "alias?";
    return hashNames[idx].alias_;
}
unittest
{
    
}

string getFullName(Hash hash)
{
    size_t idx = cast(size_t)(hash - 1);
    if (idx >= hashNames.length) return "name?";
    return hashNames[idx].full;
}
unittest
{
    
}

string getBSDName(Hash hash)
{
    size_t idx = cast(size_t)(hash - 1);
    if (idx >= hashNames.length) return "bsdtag?";
    
    immutable(HashName)* name = &hashNames[idx];
    
    return name.bsdTag ? name.bsdTag : name.full;
}
unittest
{
    
}

// Might be useless
string getGNUName(Hash hash)
{
    size_t idx = cast(size_t)(hash - 1);
    if (idx >= hashNames.length) return "gnutag?";
    
    immutable(HashName)* name = &hashNames[idx];
    
    return name.gnuTag ? name.gnuTag : name.full;
}
unittest
{
    
}

/// Get hash type from its tag name.
/// Params: tag = Tag name, like "SHA-512"
/// Return: Hash type
Hash hashFromTag(string tag)
{
    foreach (name; hashNames)
    {
        if (name.gnuTag && tag == name.gnuTag)
            return name.hash;
        else if (name.bsdTag && tag == name.bsdTag)
            return name.hash;
        else if (tag == name.full)
            return name.hash;
    }
    
    return Hash.none;
}
unittest
{
    
}

const(char)[] formatHex(Hash hash, ubyte[] result)
{
    version (BigEndian)
        enum ORDER = Order.increasing;
    else
        enum ORDER = Order.decreasing;
    
    return hash <= Hash.crc64ecma ? // is checksum?
        result.toHexString!(LetterCase.lower, ORDER) :
        result.toHexString!(LetterCase.lower);
}
unittest
{
    //TODO: Endian-based tests for checksums
}

const(char)[] formatBase64(Hash hash, ubyte[] result)
{
    return Base64.encode(result);
}
unittest
{
    //TODO: Endian-based tests for checksums
    assert(formatBase64(Hash.md5, cast(ubyte[])"test")     == "dGVzdA==");
}

ubyte[] parseHex(string input)
{
    if (input.length == 0)
        return [];
    
    // +1 to round up to 2
    ubyte[] buffer = new ubyte[(input.length + 1) / 2];
    
    bool low;
    size_t bufidx;
    foreach (char c; input)
    {
        int nib = void;
        if (c >= 'a' && c <= 'f')
            nib = (c - 'a') + 10;
        else if (c >= 'A' && c <= 'F')
            nib = (c - 'A') + 10;
        else if (c >= '0' && c <= '9')
            nib = c - '0';
        else
            continue;

        if (low) // nibble
            buffer[bufidx++] |= cast(ubyte)(nib);
        else     // high nibble
            buffer[bufidx] = cast(ubyte)(nib << 4);

        low = !low;
    }
    
    // When invalid characters are skipped, they do not contribute
    // to the total length of the slice, and since `bufidx` isn't
    // incremented, 
    return buffer[0..bufidx + low];
}
unittest
{
    assert(parseHex("")     == []);
    assert(parseHex("z")    == []);
    assert(parseHex("0")    == [ 0x00 ]);
    assert(parseHex("00")   == [ 0x00 ]);
    assert(parseHex("0000") == [ 0x00, 0x00 ]);
    assert(parseHex("1234") == [ 0x12, 0x34 ]);
    assert(parseHex("3853e2a78a247145b4aa16667736f6de") ==
        [ 0x38,0x53,0xe2,0xa7,0x8a,0x24,0x71,0x45,0xb4,0xaa,0x16,0x66,0x77,0x36,0xf6,0xde ]);
}

ubyte[] parseBase64(string input)
{
    try
        return Base64.decode(input);
    catch (Exception)
        return null;
}
unittest
{
    assert(parseBase64("dGVzdA==") == cast(ubyte[])"test");
}

/// Find hash type by entry name (filename, extension, etc.).
/// Params: path = Path, filename will be extract from this.
/// Returns: Hash type.
Hash guessHash(const(char)[] path) @safe
{
    import std.string : toLower, indexOf;
    import std.path : baseName;

    const(char)[] name = baseName(path).toLower; // filename + extension

    // Try main aliases first because "sha3" will be contained
    // in "sha386sums", for example, and must be rendered invalid.
    foreach (info; hashNames)
    {
        if (indexOf(name, info.alias_) >= 0)
            return info.hash;
    }

    // Try shorter aliases
    struct Alias
    {
        string name;
        Hash type;
    }
    static immutable Alias[] aliases = [
        { "sha3", Hash.sha3_256 }
    ];
    foreach (alias_; aliases)
    {
        if (indexOf(name, alias_.name) >= 0)
            return alias_.type;
    }

    return Hash.none;
}
@safe unittest
{
    assert(guessHash("sha1sum") == Hash.sha1);
    assert(guessHash(".SHA256SUM") == Hash.sha256);
    assert(guessHash("GE-Proton7-38.sha512sum") == Hash.sha512);
    assert(guessHash("CHECKSUM.SHA512-FreeBSD-13.1-RELEASE-amd64") == Hash.sha512);
    assert(guessHash("test.crc32") == Hash.crc32);
    assert(guessHash("test.sha256") == Hash.sha256);
    assert(guessHash("test.md5sum") == Hash.md5);
    assert(guessHash("test.sha3sums") == Hash.sha3_256);
}

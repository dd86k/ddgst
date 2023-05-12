/// Module handling multiple hash types dynamically.
///
/// Authors: dd86k <dd@dax.moe>
/// Copyright: No rights reserved
/// License: CC0
module ddh;

import std.digest;
import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc, std.digest.murmurhash;
import std.base64;
import std.format : formattedRead;
import sha3d, blake2d, xxhdd;

// Adds dynamic seeding to supported hashes
private class HashSeeded(T) if (isDigest!T && hasBlockSize!T) : WrapperDigest!T
{
    @trusted nothrow void seed(uint input)
    {
        _digest = T(input);
    }
}

private alias MurmurHash3_32_SeededDigest = HashSeeded!(MurmurHash3!32);
private alias MurmurHash3_128_32_SeededDigest = HashSeeded!(MurmurHash3!(128, 32));
private alias MurmurHash3_128_64_SeededDigest = HashSeeded!(MurmurHash3!(128, 64));

enum HashType
{
    CRC32,
    CRC64ISO,
    CRC64ECMA,
    XXHash_32,
    XXHash_64,
    XXHash3_64,
    XXHash3_128,
    MurmurHash3_32,
    MurmurHash3_128_32,
    MurmurHash3_128_64,
    MD5,
    RIPEMD160,
    SHA1,
    SHA224,
    SHA256,
    SHA384,
    SHA512,
    SHA3_224,
    SHA3_256,
    SHA3_384,
    SHA3_512,
    SHAKE128,
    SHAKE256,
    BLAKE2b512,
    BLAKE2s256,
}

enum HashCount = HashType.max + 1;
enum InvalidHash = cast(HashType)-1;

struct HashInfo
{
    HashType type;
    string fullName, alias_, tag, tag2;
}

immutable 
{
   string crc32     = "crc32";
   string crc64iso  = "crc64iso";
   string crc64ecma = "crc64ecma";
   string xxh_32    = "xxh-32";
   string xxh_64    = "xxh-64";
   string xxh3_64   = "xxh3-64";
   string xxh3_128  = "xxh3-128";
   string murmur3a  = "murmur3a";
   string murmur3c  = "murmur3c";
   string murmur3f  = "murmur3f";
   string md5       = "md5";
   string ripemd160 = "ripemd160";
   string sha1      = "sha1";
   string sha224    = "sha224";
   string sha256    = "sha256";
   string sha384    = "sha384";
   string sha512    = "sha512";
   string sha3_224  = "sha3-224";
   string sha3_256  = "sha3-256";
   string sha3_384  = "sha3-384";
   string sha3_512  = "sha3-512";
   string shake128  = "shake128";
   string shake256  = "shake256";
   string blake2b512 = "blake2b512";
   string blake2s256 = "blake2s256";
}

// Full name: Should be based on their full specification name
// Alias: Should be based on a simple lowercase name. See `openssl dgst -list` for examples.
// Tag name: Should be based on an full uppercase name. See openssl dgst output for examples.
//TODO: Alternative Alias name
//      Some aliases, like sha3-256 and ripemd160, are a little long to type
//      "sha3" and "rmd160" fit better.
//TODO: Alternative Tag name
//      For some reason, NetBSD seems to be using other names such as RMD160,
//      SHA512, etc. under OpenSSL. Is this a GNU/BSD thing?
immutable HashInfo[HashCount] hashInfo = [
    // HashType, Full, Alias, Tag (openssl), Tag2 (gnu)
    { HashType.CRC32,
        "CRC-32", crc32, "CRC32", },
    { HashType.CRC64ISO,
        "CRC-64-ISO",   crc64iso, "CRC64ISO", },
    { HashType.CRC64ECMA,
        "CRC-64-ECMA",  crc64ecma, "CRC64ECMA", },
    { HashType.XXHash_32,
        "XXHash-32",    xxh_32, "XXHASH-32", },
    { HashType.XXHash_64,
        "XXHash-64",    xxh_64, "XXHASH-64", },
    { HashType.XXHash3_64,
        "XXHash3-64",   xxh3_64, "XXHASH3-64", },
    { HashType.XXHash3_128,
        "XXHash3-128",  xxh3_128,"XXHASH3-128", },
    { HashType.MurmurHash3_32,
        "MurmurHash3-32",     murmur3a, "MURMURHASH3-32", },
    { HashType.MurmurHash3_128_32,
        "MurmurHash3-128/32", murmur3c, "MURMURHASH3-128-32", },
    { HashType.MurmurHash3_128_64,
        "MurmurHash3-128/64", murmur3f, "MURMURHASH3-128-64", },
    { HashType.MD5,
        "MD5-128",      md5, "MD5", },
    { HashType.RIPEMD160,
        "RIPEMD-160",   ripemd160, "RIPEMD160", "RMD160" },
    { HashType.SHA1,
        "SHA-1-160",    sha1, "SHA1", },
    { HashType.SHA224,
        "SHA-2-224",    sha224, "SHA2-224", "SHA224" },
    { HashType.SHA256,
        "SHA-2-256",    sha256, "SHA2-256", "SHA256" },
    { HashType.SHA384,
        "SHA-2-384",    sha384, "SHA2-384", "SHA384" },
    { HashType.SHA512,
        "SHA-2-512",    sha512, "SHA2-512", "SHA512" },
    { HashType.SHA3_224,
        "SHA-3-224",    sha3_224, "SHA3-224", },
    { HashType.SHA3_256,
        "SHA-3-256",    sha3_256, "SHA3-256", },
    { HashType.SHA3_384,
        "SHA-3-384",    sha3_384, "SHA3-384", },
    { HashType.SHA3_512,
        "SHA-3-512",    sha3_512, "SHA3-512", },
    { HashType.SHAKE128,
        "SHAKE-128",    shake128, "SHAKE-128", },
    { HashType.SHAKE256,
        "SHAKE-256",    shake256, "SHAKE-256", },
    { HashType.BLAKE2b512,
        "BLAKE2b-512",  blake2b512, "BLAKE2B-512", },
    { HashType.BLAKE2s256,
        "BLAKE2s-256",  blake2s256, "BLAKE2S-256", },
];

struct Ddh
{
    Digest digest;
    HashType type;
    ubyte[] result;
    immutable(HashInfo)* info;
    bool checksum;

    int initiate(HashType t)
    {
        final switch (t) with (HashType)
        {
        case CRC32:             digest = new CRC32Digest(); break;
        case CRC64ISO:          digest = new CRC64ISODigest(); break;
        case CRC64ECMA:         digest = new CRC64ECMADigest(); break;
        case XXHash_32:         digest = new XXH32Digest(); break;
        case XXHash_64:         digest = new XXH64Digest(); break;
        case XXHash3_64:        digest = new XXH3_64Digest(); break;
        case XXHash3_128:       digest = new XXH3_128Digest(); break;
        case MurmurHash3_32:    digest = new MurmurHash3_32_SeededDigest(); break;
        case MurmurHash3_128_32:    digest = new MurmurHash3_128_32_SeededDigest(); break;
        case MurmurHash3_128_64:    digest = new MurmurHash3_128_64_SeededDigest(); break;
        case MD5:       digest = new MD5Digest(); break;
        case RIPEMD160: digest = new RIPEMD160Digest(); break;
        case SHA1:      digest = new SHA1Digest(); break;
        case SHA224:    digest = new SHA224Digest(); break;
        case SHA256:    digest = new SHA256Digest(); break;
        case SHA384:    digest = new SHA384Digest(); break;
        case SHA512:    digest = new SHA512Digest(); break;
        case SHA3_224:  digest = new SHA3_224Digest(); break;
        case SHA3_256:  digest = new SHA3_256Digest(); break;
        case SHA3_384:  digest = new SHA3_384Digest(); break;
        case SHA3_512:  digest = new SHA3_512Digest(); break;
        case SHAKE128:  digest = new SHAKE128Digest(); break;
        case SHAKE256:  digest = new SHAKE256Digest(); break;
        case BLAKE2b512:    digest = new BLAKE2b512Digest(); break;
        case BLAKE2s256:    digest = new BLAKE2s256Digest(); break;
        }

        type = t;
        info = &hashInfo[t];
        checksum = t <= HashType.CRC64ECMA;

        return 0;
    }

    void key(const(ubyte)[] input...)
    {
        switch (type) with (HashType)
        {
        case BLAKE2b512: (cast(BLAKE2b512Digest)digest).key(input); break;
        case BLAKE2s256: (cast(BLAKE2s256Digest)digest).key(input); break;
        default: throw new Exception("Digest does not support keying.");
        }
    }

    void seed(uint input)
    {
        switch (type) with (HashType)
        {
        case MurmurHash3_32:     (cast(MurmurHash3_32_SeededDigest)digest).seed(input); break;
        case MurmurHash3_128_32: (cast(MurmurHash3_128_32_SeededDigest)digest).seed(input); break;
        case MurmurHash3_128_64: (cast(MurmurHash3_128_64_SeededDigest)digest).seed(input); break;
        default: throw new Exception("Digest does not support seeding.");
        }
    }

    void reset()
    {
        digest.reset();
    }

    size_t length()
    {
        return digest.length();
    }

    void put(scope const(ubyte)[] input...)
    {
        digest.put(input);
    }

    ubyte[] finish()
    {
        return (result = digest.finish());
    }

    const(char)[] toHex()
    {
        //TODO: Test if endianness messes results with checksums
        return checksum ?
            result.toHexString!(LetterCase.lower, Order.decreasing) :
            result.toHexString!(LetterCase.lower);
    }

    const(char)[] toBase64()
    {
        return Base64.encode(result);
    }

    string fullName()
    {
        return info.fullName;
    }

    string aliasName()
    {
        return info.alias_;
    }

    string tagName()
    {
        return info.tag;
    }
}

/// 
@system unittest
{
    import std.conv : hexString;

    Ddh ddh = void;
    ddh.initiate(HashType.CRC32);
    ddh.put(cast(ubyte[]) "abc");
    assert(ddh.finish() == cast(ubyte[]) hexString!"c2412435");
    assert(ddh.toHex() == "352441c2");

    ddh.initiate(HashType.SHA3_256);
    ddh.put(cast(ubyte[]) "abc");
    assert(ddh.finish() == cast(ubyte[]) hexString!(
            "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"));
    assert(ddh.toHex() ==
            "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532");
}

/// Read a formatted GNU tag line.
/// Params:
///     line = Full GNU formatted tag string
///     hash = Hexadecimal hash string (e.g., "aabbccdd")
///     file = File string (e.g., "nightly.iso")
/// Returns: True on error.
bool readGNULine(string line, ref const(char)[] hash, ref const(char)[] file)
{
    // Tested to work with one or many spaces
    return formattedRead(line, "%s %s", hash, file) != 2;
}

unittest
{
    string line = "f6067df486cbdbb0aac026b799b26261c92734a3  LICENSE";
    const(char)[] hash, file;
    assert(readGNULine(line, hash, file) == false);
    assert(hash == "f6067df486cbdbb0aac026b799b26261c92734a3");
    assert(file == "LICENSE");
}

/// Read a formatted BSD tag line.
/// Params:
///     line = Full BSD formatted tag string
///     type = Hash type string (e.g., "SHA256")
///     file = File string (e.g., "nightly.iso")
///     hash = Hexadecimal hash string (e.g., "8080aabb")
/// Returns: True on error.
bool readBSDLine(string line,
    ref const(char)[] type, ref const(char)[] file, ref const(char)[] hash)
{
    // Tested to work with and without spaces
    return formattedRead(line, "%s (%s) = %s", type, file, hash) != 3;
}

unittest
{
    string line =
        "SHA256 (Fedora-Workstation-Live-x86_64-36-1.5.iso) = " ~
        "80169891cb10c679cdc31dc035dab9aae3e874395adc5229f0fe5cfcc111cc8c";
    const(char)[] type, file, hash;
    assert(readBSDLine(line, type, file, hash) == false);
    assert(type == "SHA256");
    assert(file == "Fedora-Workstation-Live-x86_64-36-1.5.iso");
    assert(hash == "80169891cb10c679cdc31dc035dab9aae3e874395adc5229f0fe5cfcc111cc8c");
}

/// Read a formatted SRI tag line.
/// Params:
///     line = Full RSI formatted tag string
///     type = Hash type string (e.g., "md5")
///     hash = Base64 hash string (e.g., "OFPip4okcUW0qhZmdzb23g==")
bool readSRILine(string line, ref const(char)[] type, ref const(char)[] hash)
{
    return formattedRead(line, "%s-%s", type, hash) != 2;
}

unittest
{
    string line = "sha1-9gZ99IbL27CqwCa3mbJiYcknNKM=";
    const(char)[] type, hash;
    assert(readSRILine(line, type, hash) == false);
    assert(type == "sha1");
    assert(hash == "9gZ99IbL27CqwCa3mbJiYcknNKM=");
}

/+bool readPGPMessage(string line)
{
        /* PGP Message example:
        -----BEGIN PGP SIGNED MESSAGE-----
        Hash: SHA256

        # Fedora-Workstation-Live-x86_64-36-1.5.iso: 2018148352 bytes
        SHA256 (Fedora-Workstation-Live-x86_64-36-1.5.iso) = 80169891cb10c679cdc31dc035dab9aae3e874395adc5229f0fe5cfcc111cc8c
        -----BEGIN PGP SIGNATURE-----
        ...*/
}+/

/// Guess hash type by extension name.
/// Params: path = Path, filename will be extract from this.
/// Returns: Hash type.
HashType guessHash(const(char)[] path) @safe
{
    import std.string : toLower, indexOf;
    import std.path : extension, baseName, globMatch, CaseSensitive;
    import std.algorithm.searching : canFind, startsWith;

    const(char)[] name = baseName(path).toLower;

    foreach (info; hashInfo)
    {
        if (indexOf(name, info.alias_) >= 0)
            return info.type;
    }

    // aliases
    struct Alias
    {
        string name;
        HashType type;
    }
    static immutable Alias[] aliases = [
        { "sha3", HashType.SHA3_256 }
    ];
    foreach (alias_; aliases)
    {
        if (indexOf(name, alias_.name) >= 0)
            return alias_.type;
    }

    return InvalidHash;
}

@safe unittest
{
    assert(guessHash("sha1sum") == HashType.SHA1);
    assert(guessHash(".SHA256SUM") == HashType.SHA256);
    assert(guessHash("GE-Proton7-38.sha512sum") == HashType.SHA512);
    assert(guessHash("CHECKSUM.SHA512-FreeBSD-13.1-RELEASE-amd64") == HashType.SHA512);
    assert(guessHash("test.crc32") == HashType.CRC32);
    assert(guessHash("test.sha256") == HashType.SHA256);
    assert(guessHash("test.md5sum") == HashType.MD5);
    assert(guessHash("test.sha3sums") == HashType.SHA3_256);
}

// Check by context
// This can be a GNU list, BSD list, or PGP signed message with tag
/*HashType guessHashFile(string content) @safe
{
        
        
}

@safe unittest
{
}*/

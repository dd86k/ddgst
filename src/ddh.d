/**
 * Main module that handles various hashing algorithms at run-time.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module ddh;

import std.digest;
import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc, std.digest.murmurhash;
import sha3d, blake2d;
import std.base64;

private alias MurmurHash3_32Digest = WrapperDigest!(MurmurHash3!32);
private alias MurmurHash3_128Digest = WrapperDigest!(MurmurHash3!(128, 64));

enum HashType
{
	CRC32,
	CRC64ISO,
	CRC64ECMA,
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
	MurMurHash3_32,
	MurMurHash3_128,
}
enum HashCount = HashType.max + 1;

struct HashInfo
{
	HashType type;
	string fullName, aliasName, tagName;
}

// Full name: Should be based on their full specification name
// Alias: Should be based on a simple lowercase name. See `openssl dgst -list` for examples.
// Tag name: Should be based on an full uppercase name. See openssl dgst output for examples.
immutable HashInfo[HashCount] hashInfo = [
	{ HashType.CRC32,	"CRC-32", "crc32", "CRC32", },
	{ HashType.CRC64ISO,	"CRC-64-ISO", "crc64iso", "CRC64ISO", },
	{ HashType.CRC64ECMA,	"CRC-64-ECMA", "crc64ecma", "CRC64ECMA", },
	{ HashType.MD5,	"MD5-128", "md5", "MD5", },
	{ HashType.RIPEMD160,	"RIPEMD-160", "ripemd160", "RIPEMD160", },
	{ HashType.SHA1,	"SHA-1-160", "sha1", "SHA1", },
	{ HashType.SHA224,	"SHA-2-224", "sha224", "SHA2-224", },
	{ HashType.SHA256,	"SHA-2-256", "sha256", "SHA2-256", },
	{ HashType.SHA384,	"SHA-2-384", "sha384", "SHA2-384", },
	{ HashType.SHA512,	"SHA-2-512", "sha512", "SHA2-512", },
	{ HashType.SHA3_224,	"SHA-3-224", "sha3-224", "SHA3-224", },
	{ HashType.SHA3_256,	"SHA-3-256", "sha3-256", "SHA3-256", },
	{ HashType.SHA3_384,	"SHA-3-384", "sha3-384", "SHA3-384", },
	{ HashType.SHA3_512,	"SHA-3-512", "sha3-512", "SHA3-512", },
	{ HashType.SHAKE128,	"SHAKE-128", "shake128", "SHAKE-128", },
	{ HashType.SHAKE256,	"SHAKE-256", "shake256", "SHAKE-256", },
	{ HashType.BLAKE2b512,	"BLAKE2b-512", "blake2b512", "BLAKE2B-512", },
	{ HashType.BLAKE2s256,	"BLAKE2s-256", "blake2s256", "BLAKE2S-256", },
	{ HashType.MurMurHash3_32,	"MurmurHash3-32",  "murmurhash3-32",  "MURMURHASH3-32", },
	{ HashType.MurMurHash3_128,	"MurmurHash3-128", "murmurhash3-128", "MURMURHASH3-128", },
];

private enum
{
	HASH_LARGEST = 512,	// in bits
	HASH_LARGEST_SIZE = HASH_LARGEST / 8,	// in bytes
	HASH_LARGEST_STRING = HASH_LARGEST_SIZE * 2,	// in chars
}

struct Ddh
{
	Digest hash;
	HashType type;
	ubyte[] result;
	immutable(HashInfo) *info;
	bool checksum;
	
	int initiate(HashType t)
	{
		//TODO: Maybe I can get the .ctor into the table
		final switch (t) with (HashType)
		{
		case CRC32:	hash = new CRC32Digest(); break;
		case CRC64ISO:	hash = new CRC64ISODigest(); break;
		case CRC64ECMA:	hash = new CRC64ECMADigest(); break;
		case MD5:	hash = new MD5Digest(); break;
		case RIPEMD160:	hash = new RIPEMD160Digest(); break;
		case SHA1:	hash = new SHA1Digest(); break;
		case SHA224:	hash = new SHA224Digest(); break;
		case SHA256:	hash = new SHA256Digest(); break;
		case SHA384:	hash = new SHA384Digest(); break;
		case SHA512:	hash = new SHA512Digest(); break;
		case SHA3_224:	hash = new SHA3_224Digest(); break;
		case SHA3_256:	hash = new SHA3_256Digest(); break;
		case SHA3_384:	hash = new SHA3_384Digest(); break;
		case SHA3_512:	hash = new SHA3_512Digest(); break;
		case SHAKE128:	hash = new SHAKE128Digest(); break;
		case SHAKE256:	hash = new SHAKE256Digest(); break;
		case BLAKE2b512:	hash = new BLAKE2b512Digest(); break;
		case BLAKE2s256:	hash = new BLAKE2s256Digest(); break;
		case MurMurHash3_32:	hash = new MurmurHash3_32Digest(); break;
		case MurMurHash3_128:	hash = new MurmurHash3_128Digest(); break;
		}
		
		type = t;
		info = &hashInfo[t];
		checksum = t < HashType.MD5;
		
		return 0;
	}
	
	void reset()
	{
		hash.reset();
	}
	
	size_t length()
	{
		return hash.length();
	}
	
	void put(scope const(ubyte)[] input...)
	{
		hash.put(input);
	}
	
	ubyte[] finish()
	{
		return (result = hash.finish());
	}
	
	const(char)[] toHex()
	{
		//TODO: Test if endianness messes results with checksums
		return checksum ?
			toHexString!(LetterCase.lower, Order.decreasing)(result) :
			toHexString!(LetterCase.lower)(result);
	}
	
	const(char)[] toBase64()
	{
		return Base64.encode(result);
	}
	
	string fullName()  { return info.fullName; }
	string aliasName() { return info.aliasName; }
	string tagName()   { return info.tagName; }
}

/// 
@system unittest
{
	import std.conv : hexString;
	
	Ddh ddh = void;
	ddh.initiate(HashType.CRC32);
	ddh.put(cast(ubyte[])"abc");
	assert(ddh.finish() == cast(ubyte[]) hexString!"c2412435");
	assert(ddh.toHex() == "352441c2");
	
	ddh.initiate(HashType.SHA3_256);
	ddh.put(cast(ubyte[])"abc");
	assert(ddh.finish() == cast(ubyte[]) hexString!(
		"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"));
	assert(ddh.toHex() ==
		"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532");
}
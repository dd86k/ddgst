/**
 * Main module that handles various hashing algorithms at run-time.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module ddh;

private import std.digest;
private import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc;
private import sha3d;

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
}

struct HashInfo
{
	HashType type;
	string fullName, aliasName, tagName;
}

immutable HashInfo[16] hashInfo = [
	{ HashType.CRC32,	"CRC-32", "crc32", "CRC32", },
	{ HashType.CRC64ISO,	"CRC-64-ISO", "crc64iso", "CRC64ISO", },
	{ HashType.CRC64ECMA,	"CRC-64-ECMA", "crc64ecma", "CRC64ECMA", },
	{ HashType.MD5,	"MD5-128", "md5", "MD5", },
	{ HashType.RIPEMD160,	"RIPEMD-160", "ripemd160", "RIPEMD160", },
	{ HashType.SHA1,	"SHA-1-160", "sha1", "SHA1", },
	{ HashType.SHA224,	"SHA-2-224", "sha224", "SHA224", },
	{ HashType.SHA256,	"SHA-2-256", "sha256", "SHA256", },
	{ HashType.SHA384,	"SHA-2-384", "sha384", "SHA384", },
	{ HashType.SHA512,	"SHA-2-512", "sha512", "SHA512", },
	{ HashType.SHA3_224,	"SHA-3-224", "sha3-224", "SHA3_224", },
	{ HashType.SHA3_256,	"SHA-3-256", "sha3-256", "SHA3_256", },
	{ HashType.SHA3_384,	"SHA-3-384", "sha3-384", "SHA3_384", },
	{ HashType.SHA3_512,	"SHA-3-512", "sha3-512", "SHA3_512", },
	{ HashType.SHAKE128,	"SHAKE-128", "shake128", "SHAKE128", },
	{ HashType.SHAKE256,	"SHAKE-256", "shake256", "SHAKE256", },
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
		}
		
		type = t;
		info = &hashInfo[t];
		
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
	
	const(char)[] toDigest()
	{
		//TODO: Test if endianness messes results with checksums
		switch (type) with (HashType)
		{
		case CRC32, CRC64ISO, CRC64ECMA:
			return toHexString!(LetterCase.lower, Order.decreasing)(result);
		default:
			return toHexString!(LetterCase.lower)(result);
		}
	}
	
	string fullName()
	{
		return info.fullName;
	}
	
	string aliasName()
	{
		return info.aliasName;
	}
	
	string tagName()
	{
		return info.tagName;
	}
}

/// 
@system unittest
{
	import std.conv : hexString;
	
	Ddh ddh = void;
	ddh.initiate(HashType.CRC32);
	ddh.put(cast(ubyte[])"abc");
	assert(ddh.finish() == cast(ubyte[]) hexString!"c2412435");
	assert(ddh.toDigest() == "352441c2");
	
	ddh.initiate(HashType.SHA3_256);
	ddh.put(cast(ubyte[])"abc");
	assert(ddh.finish() ==
		cast(ubyte[]) hexString!"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532");
	assert(ddh.toDigest() ==
		"3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532");
}
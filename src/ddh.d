/**
 * Main module that handles various hashing algorithms at run-time.
 *
 * Authors: dd86k <dd@dax.moe>
 * Copyright: None
 * License: Public domain
 */
module ddh;

private import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc;
private import sha3d.sha3;

version (PrintInfo)
{
	pragma(msg, "CRC32.sizeof\t",	CRC32.sizeof);
	pragma(msg, "CRC64ISO.sizeof\t",	CRC64ISO.sizeof);
	pragma(msg, "CRC64ECMA.sizeof\t",	CRC64ECMA.sizeof);
	pragma(msg, "MD5.sizeof\t",	MD5.sizeof);
	pragma(msg, "RIPEMD160.sizeof\t",	RIPEMD160.sizeof);
	pragma(msg, "SHA1.sizeof\t",	SHA1.sizeof);
	pragma(msg, "SHA224.sizeof\t",	SHA224.sizeof);
	pragma(msg, "SHA256.sizeof\t",	SHA256.sizeof);
	pragma(msg, "SHA384.sizeof\t",	SHA384.sizeof);
	pragma(msg, "SHA512.sizeof\t",	SHA512.sizeof);
	pragma(msg, "SHA3_224.sizeof\t",	SHA3_224.sizeof);
	pragma(msg, "SHA3_256.sizeof\t",	SHA3_256.sizeof);
	pragma(msg, "SHA3_384.sizeof\t",	SHA3_384.sizeof);
	pragma(msg, "SHA3_512.sizeof\t",	SHA3_512.sizeof);
	pragma(msg, "SHAKE128.sizeof\t",	SHAKE128.sizeof);
	pragma(msg, "SHAKE256.sizeof\t",	SHAKE256.sizeof);
	pragma(msg, "BLAKE2.sizeof\t",	BLAKE2.sizeof);
	pragma(msg, "BLAKE2b.sizeof\t",	BLAKE2b.sizeof);
	pragma(msg, "BLAKE2s.sizeof\t",	BLAKE2s.sizeof);
}

/// Choose which checksum or hash will be used
enum DDHType
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

template DGSTSZ(DDHType type)
{
	static if (type == DDHType.CRC32)
	{
		enum DGSTSZ = BITS!(32);
	}
	else static if (type == DDHType.CRC64ISO)
	{
		enum DGSTSZ = BITS!(64);
	}
	else static if (type == DDHType.CRC64ECMA)
	{
		enum DGSTSZ = BITS!(64);
	}
	else static if (type == DDHType.MD5)
	{
		enum DGSTSZ = BITS!(128);
	}
	else static if (type == DDHType.RIPEMD160)
	{
		enum DGSTSZ = BITS!(160);
	}
	else static if (type == DDHType.SHA1)
	{
		enum DGSTSZ = BITS!(160);
	}
	else static if (type == DDHType.SHA224)
	{
		enum DGSTSZ = BITS!(224);
	}
	else static if (type == DDHType.SHA256)
	{
		enum DGSTSZ = BITS!(256);
	}
	else static if (type == DDHType.SHA384)
	{
		enum DGSTSZ = BITS!(384);
	}
	else static if (type == DDHType.SHA512)
	{
		enum DGSTSZ = BITS!(512);
	}
	else static if (type == DDHType.SHA3_224)
	{
		enum DGSTSZ = BITS!(224);
	}
	else static if (type == DDHType.SHA3_256)
	{
		enum DGSTSZ = BITS!(256);
	}
	else static if (type == DDHType.SHA3_384)
	{
		enum DGSTSZ = BITS!(384);
	}
	else static if (type == DDHType.SHA3_512)
	{
		enum DGSTSZ = BITS!(512);
	}
	else static if (type == DDHType.SHAKE128)
	{
		enum DGSTSZ = BITS!(128);
	}
	else static if (type == DDHType.SHAKE256)
	{
		enum DGSTSZ = BITS!(256);
	}
	else static assert(0, "Implement DGSTSZ");
}

private alias func_compute = extern (C) void function(DDH_INTERNALS_T*, ubyte[]);
private alias func_finish  = extern (C) ubyte[] function(DDH_INTERNALS_T*);
private alias func_reset   = extern (C) void function(DDH_INTERNALS_T*);

/// Main structure
struct DDH_T
{
	DDHType type;	/// Checksum or hash type
	func_compute compute;	/// compute function ptr
	func_finish finish;	/// finish function ptr
	func_reset reset;	/// reset function ptr
	union
	{
		void *voidptr;	/// Void pointer for allocation
		DDH_INTERNALS_T *inptr;	/// Internal pointer for allocation
	}
	bool internalInit;
}

/// Internals for DDH_T
private struct DDH_INTERNALS_T
{
	enum BIGGEST = BITS!(512);
	union
	{
		CRC32 crc32;	/// CRC-32
		CRC64ISO crc64iso;	/// CRC-64-ISO
		CRC64ECMA crc64ecma;	/// CRC-64-ECMA
		MD5 md5;	/// MD-5
		RIPEMD160 ripemd160;	/// RIPEMD-160
		SHA1 sha1;	/// SHA-1
		SHA224 sha224;	/// SHA-2-224
		SHA256 sha256;	/// SHA-2-256
		SHA384 sha384;	/// SHA-2-384
		SHA512 sha512;	/// SHA-2-512
		SHA3_224 sha3_224;	/// SHA-3-256
		SHA3_256 sha3_256;	/// SHA-3-256
		SHA3_384 sha3_384;	/// SHA-3-256
		SHA3_512 sha3_512;	/// SHA-3-256
		SHAKE128 shake128;	/// SHAKE-128
		SHAKE256 shake256;	/// SHAKE-256
	}
	union
	{
		ubyte[BIGGEST] buffer;	/// Internal buffer for raw result
		ulong bufferu64;	/// Internal union type
		uint bufferu32;	/// Internal union type
	}
	size_t bufferlen;	/// Internal buffer raw result size
	char[BIGGEST * 2] result;	/// Internal buffer for formatted result
}

//TODO: Template that lets me initiate structure
//      In a cute way

/// 
struct DDHInfo
{
	DDHType type;	/// static action
	uint size;	/// static digest_size
	string name;	/// static name
	string basename;	/// static basename
	string tagname;	/// BSD-style tag name
	func_compute fcomp;	/// static fcomp
	func_finish fdone;	/// static fdone
	func_reset freset;	/// static freset
}

/// Structure information
immutable DDHInfo[] meta_info = [
	{
		DDHType.CRC32, DGSTSZ!(DDHType.CRC32),
		"CRC-32", "crc32", "CRC32",
		&ddh_compute!(DDHType.CRC32),
		&ddh_finish!(DDHType.CRC32),
		&ddh_reset!(DDHType.CRC32),
	},
	{
		DDHType.CRC64ISO, DGSTSZ!(DDHType.CRC64ISO),
		"CRC-64-ISO", "crc64iso", "CRC64ISO",
		&ddh_compute!(DDHType.CRC64ISO),
		&ddh_finish!(DDHType.CRC64ISO),
		&ddh_reset!(DDHType.CRC64ISO),
	},
	{
		DDHType.CRC64ECMA, DGSTSZ!(DDHType.CRC64ECMA),
		"CRC-64-ECMA", "crc64ecma", "CRC64ECMA",
		&ddh_compute!(DDHType.CRC64ECMA),
		&ddh_finish!(DDHType.CRC64ECMA),
		&ddh_reset!(DDHType.CRC64ECMA),
	},
	{
		DDHType.MD5, DGSTSZ!(DDHType.MD5),
		"MD5-128", "md5", "MD5",
		&ddh_compute!(DDHType.MD5),
		&ddh_finish!(DDHType.MD5),
		&ddh_reset!(DDHType.MD5)
	},
	{
		DDHType.RIPEMD160, DGSTSZ!(DDHType.RIPEMD160),
		"RIPEMD-160", "ripemd160", "RIPEMD160",
		&ddh_compute!(DDHType.RIPEMD160),
		&ddh_finish!(DDHType.RIPEMD160),
		&ddh_reset!(DDHType.RIPEMD160)
	},
	{
		DDHType.SHA1, DGSTSZ!(DDHType.SHA1),
		"SHA-1-160", "sha1", "SHA1",
		&ddh_compute!(DDHType.SHA1),
		&ddh_finish!(DDHType.SHA1),
		&ddh_reset!(DDHType.SHA1)
	},
	{
		DDHType.SHA224, DGSTSZ!(DDHType.SHA224),
		"SHA-2-224", "sha224", "SHA224",
		&ddh_compute!(DDHType.SHA224),
		&ddh_finish!(DDHType.SHA224),
		&ddh_reset!(DDHType.SHA224)
	},
	{
		DDHType.SHA256, DGSTSZ!(DDHType.SHA256),
		"SHA-2-256", "sha256", "SHA256",
		&ddh_compute!(DDHType.SHA256),
		&ddh_finish!(DDHType.SHA256),
		&ddh_reset!(DDHType.SHA256)
	},
	{
		DDHType.SHA384, DGSTSZ!(DDHType.SHA384),
		"SHA-2-384", "sha384", "SHA384",
		&ddh_compute!(DDHType.SHA384),
		&ddh_finish!(DDHType.SHA384),
		&ddh_reset!(DDHType.SHA384)
	},
	{
		DDHType.SHA512, DGSTSZ!(DDHType.SHA512),
		"SHA-2-512", "sha512", "SHA512",
		&ddh_compute!(DDHType.SHA512),
		&ddh_finish!(DDHType.SHA512),
		&ddh_reset!(DDHType.SHA512)
	},
	{
		DDHType.SHA3_224, DGSTSZ!(DDHType.SHA3_224),
		"SHA-3-224", "sha3-224", "SHA3_224",
		&ddh_compute!(DDHType.SHA3_224),
		&ddh_finish!(DDHType.SHA3_224),
		&ddh_reset!(DDHType.SHA3_224)
	},
	{
		DDHType.SHA3_256, DGSTSZ!(DDHType.SHA3_256),
		"SHA-3-256", "sha3-256", "SHA3_256",
		&ddh_compute!(DDHType.SHA3_256),
		&ddh_finish!(DDHType.SHA3_256),
		&ddh_reset!(DDHType.SHA3_256)
	},
	{
		DDHType.SHA3_384, DGSTSZ!(DDHType.SHA3_384),
		"SHA-3-384", "sha3-384", "SHA3_384",
		&ddh_compute!(DDHType.SHA3_384),
		&ddh_finish!(DDHType.SHA3_384),
		&ddh_reset!(DDHType.SHA3_384)
	},
	{
		DDHType.SHA3_512, DGSTSZ!(DDHType.SHA3_512),
		"SHA-3-512", "sha3-512", "SHA3_512",
		&ddh_compute!(DDHType.SHA3_512),
		&ddh_finish!(DDHType.SHA3_512),
		&ddh_reset!(DDHType.SHA3_512)
	},
	{
		DDHType.SHAKE128, DGSTSZ!(DDHType.SHAKE128),
		"SHAKE-128", "shake128", "SHAKE128",
		&ddh_compute!(DDHType.SHAKE128),
		&ddh_finish!(DDHType.SHAKE128),
		&ddh_reset!(DDHType.SHAKE128)
	},
	{
		DDHType.SHAKE256, DGSTSZ!(DDHType.SHAKE128),
		"SHAKE-256", "shake256", "SHAKE256",
		&ddh_compute!(DDHType.SHAKE256),
		&ddh_finish!(DDHType.SHAKE256),
		&ddh_reset!(DDHType.SHAKE256)
	}
];
static assert(meta_info.length == DDHType.max + 1);
// GDC 10.0 supports static foreach, GDC 9.3 does not
unittest
{
	foreach (i, DDHInfo info; meta_info)
	{
		assert(info.type == cast(DDHType)i);
	}
}

// Helps converting bits to byte sizes, avoids errors
private template BITS(int n) if (n % 8 == 0) { enum { BITS = n >> 3 } }
/// BITS test
unittest { static assert(BITS!(32) == 4); }

/// Initiates a DDH_T structure with an DDHType value.
/// Params:
/// 	ddh = DDH_T structure
/// 	type = DDHType value
/// Returns: True on error
bool ddh_init(ref DDH_T ddh, DDHType type)
{
	import core.stdc.stdlib : malloc;
	
	if (ddh.internalInit == false)
	{
		ddh.voidptr = malloc(DDH_INTERNALS_T.sizeof);
		if (ddh.voidptr == null)
			return true;
		ddh.internalInit = true;
	}
	
	size_t i = ddh.type = type;
	ddh.compute = meta_info[i].fcomp;
	ddh.finish  = meta_info[i].fdone;
	ddh.reset   = meta_info[i].freset;
	ddh.inptr.bufferlen = meta_info[i].size;
	
	ddh_reset(ddh);
	
	return false;
}

/// Get the digest size in bytes
/// Returns: Digest size
uint ddh_digest_size(ref DDH_T ddh)
{
	return meta_info[ddh.type].size;
}

/// Compute a block of data
/// Params:
/// 	ddh = DDH_T structure
/// 	data = Byte array
void ddh_compute(ref DDH_T ddh, ubyte[] data)
{
	ddh.compute(ddh.inptr, data);
}

/// Finalize digest or checksum
/// Params: ddh = DDH_T structure
/// Returns: Raw digest slice
ubyte[] ddh_finish(ref DDH_T ddh)
{
	return ddh.finish(ddh.inptr);
}

/// Re-initiates the DDH session.
/// Params: ddh = DDH_T structure
void ddh_reset(ref DDH_T ddh)
{
	ddh.reset(ddh.inptr);
}

/// Finalize digest or checksum and return formatted 
/// Finalize and return formatted diggest
/// Params: ddh = DDH_T structure
/// Returns: Formatted digest
char[] ddh_string(ref DDH_T ddh)
{
	import std.format : sformat;
	
	switch (ddh.type)
	{
	case DDHType.CRC64ISO, DDHType.CRC64ECMA:	// 64 bits
		return sformat(ddh.inptr.result, "%016x", ddh.inptr.bufferu64);
	case DDHType.CRC32:	// 32 bits
		return sformat(ddh.inptr.result, "%08x", ddh.inptr.bufferu32);
	default:	// Of any length
		const size_t len = ddh.inptr.bufferlen;
		ubyte *tbuf = ddh.inptr.buffer.ptr;
		char  *rbuf = ddh.inptr.result.ptr;
		for (size_t i; i < len; ++i) {
			ubyte v = tbuf[i];
			rbuf[1] = fasthexchar(v & 0xF);
			rbuf[0] = fasthexchar(v >> 4);
			rbuf += 2;
		}
		return ddh.inptr.result[0..len << 1];
	}
}

private:
extern (C):

pragma(inline, true)
char fasthexchar(ubyte v) nothrow pure @nogc @safe
{
	return cast(char)(v <= 9 ? v + 48 : v + 87);
}

void ddh_compute(DDHType type)(DDH_INTERNALS_T *v, ubyte[] data)
{
	static if (type == DDHType.CRC32)
	{
		v.crc32.put(data);
	}
	else static if (type == DDHType.CRC64ISO)
	{
		v.crc64iso.put(data);
	}
	else static if (type == DDHType.CRC64ECMA)
	{
		v.crc64ecma.put(data);
	}
	else static if (type == DDHType.MD5)
	{
		v.md5.put(data);
	}
	else static if (type == DDHType.RIPEMD160)
	{
		v.ripemd160.put(data);
	}
	else static if (type == DDHType.SHA1)
	{
		v.sha1.put(data);
	}
	else static if (type == DDHType.SHA224)
	{
		v.sha224.put(data);
	}
	else static if (type == DDHType.SHA256)
	{
		v.sha256.put(data);
	}
	else static if (type == DDHType.SHA384)
	{
		v.sha384.put(data);
	}
	else static if (type == DDHType.SHA512)
	{
		v.sha512.put(data);
	}
	else static if (type == DDHType.SHA3_224)
	{
		v.sha3_224.put(data);
	}
	else static if (type == DDHType.SHA3_256)
	{
		v.sha3_256.put(data);
	}
	else static if (type == DDHType.SHA3_384)
	{
		v.sha3_384.put(data);
	}
	else static if (type == DDHType.SHA3_512)
	{
		v.sha3_512.put(data);
	}
	else static if (type == DDHType.SHAKE128)
	{
		v.shake128.put(data);
	}
	else static if (type == DDHType.SHAKE256)
	{
		v.shake256.put(data);
	}
	else static assert(0, "Implement ddh_compute");
}

ubyte[] ddh_finish(DDHType type)(DDH_INTERNALS_T *v)
{
	static if (type == DDHType.CRC32)
	{
		return v.buffer[0..DGSTSZ!(DDHType.CRC32)] = v.crc32.finish()[];
	}
	else static if (type == DDHType.CRC64ISO)
	{
		return v.buffer[0..DGSTSZ!(DDHType.CRC64ISO)] = v.crc64iso.finish()[];
	}
	else static if (type == DDHType.CRC64ECMA)
	{
		return v.buffer[0..DGSTSZ!(DDHType.CRC64ECMA)] = v.crc64ecma.finish()[];
	}
	else static if (type == DDHType.MD5)
	{
		return v.buffer[0..DGSTSZ!(DDHType.MD5)] = v.md5.finish()[];
	}
	else static if (type == DDHType.RIPEMD160)
	{
		return v.buffer[0..DGSTSZ!(DDHType.RIPEMD160)] = v.ripemd160.finish()[];
	}
	else static if (type == DDHType.SHA1)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA1)] = v.sha1.finish()[];
	}
	else static if (type == DDHType.SHA224)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA224)] = v.sha224.finish()[];
	}
	else static if (type == DDHType.SHA256)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA256)] = v.sha256.finish()[];
	}
	else static if (type == DDHType.SHA384)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA384)] = v.sha384.finish()[];
	}
	else static if (type == DDHType.SHA512)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA512)] = v.sha512.finish()[];
	}
	else static if (type == DDHType.SHA3_224)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA3_224)] = v.sha3_224.finish()[];
	}
	else static if (type == DDHType.SHA3_256)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA3_256)] = v.sha3_256.finish()[];
	}
	else static if (type == DDHType.SHA3_384)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA3_384)] = v.sha3_384.finish()[];
	}
	else static if (type == DDHType.SHA3_512)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHA3_512)] = v.sha3_512.finish()[];
	}
	else static if (type == DDHType.SHAKE128)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHAKE128)] = v.shake128.finish()[];
	}
	else static if (type == DDHType.SHAKE256)
	{
		return v.buffer[0..DGSTSZ!(DDHType.SHAKE256)] = v.shake256.finish()[];
	}
	else static assert(0, "Implement ddh_compute");
}

void ddh_reset(DDHType type)(DDH_INTERNALS_T *v)
{
	static if (type == DDHType.CRC32)
	{
		v.crc32.start();
	}
	else static if (type == DDHType.CRC64ISO)
	{
		v.crc64iso.start();
	}
	else static if (type == DDHType.CRC64ECMA)
	{
		v.crc64ecma.start();
	}
	else static if (type == DDHType.MD5)
	{
		v.md5.start();
	}
	else static if (type == DDHType.RIPEMD160)
	{
		v.ripemd160.start();
	}
	else static if (type == DDHType.SHA1)
	{
		v.sha1.start();
	}
	else static if (type == DDHType.SHA224)
	{
		v.sha224.start();
	}
	else static if (type == DDHType.SHA256)
	{
		v.sha256.start();
	}
	else static if (type == DDHType.SHA384)
	{
		v.sha384.start();
	}
	else static if (type == DDHType.SHA512)
	{
		v.sha512.start();
	}
	else static if (type == DDHType.SHA3_224)
	{
		v.sha3_224.start();
	}
	else static if (type == DDHType.SHA3_256)
	{
		v.sha3_256.start();
	}
	else static if (type == DDHType.SHA3_384)
	{
		v.sha3_384.start();
	}
	else static if (type == DDHType.SHA3_512)
	{
		v.sha3_512.start();
	}
	else static if (type == DDHType.SHAKE128)
	{
		v.shake128.start();
	}
	else static if (type == DDHType.SHAKE256)
	{
		v.shake256.start();
	}
	else static assert(0, "Implement ddh_compute");
}

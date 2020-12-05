module ddh.ddh;

private import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc;
private import ddh.hash.sha3;

/// Last error code
enum DDHError
{
	None,
	CRT
}

/// Choose which checksum or hash will be used
enum DDHAction
{
	SumCRC32,
	SumCRC64ISO,
	SumCRC64ECMA,
	HashMD5,
	HashRIPEMD160,
	HashSHA1,
	HashSHA224,
	HashSHA256,
	HashSHA384,
	HashSHA512,
	HashSHA3_224,
	HashSHA3_256,
	HashSHA3_384,
	HashSHA3_512,
	HashSHAKE128,
	HashSHAKE256,
}

private alias func_compute = extern (C) void function(DDH_INTERNALS_T*, ubyte[]);
private alias func_finish  = extern (C) ubyte[] function(DDH_INTERNALS_T*);
private alias func_reset   = extern (C) void function(DDH_INTERNALS_T*);

/// Main structure
struct DDH_T
{
	DDHAction action;	/// Checksum/Hash
	func_compute compute;	/// compute function ptr
	func_finish finish;	/// finish function ptr
	func_reset reset;	/// reset function ptr
	union
	{
		void *voidptr;	/// Void pointer for allocation
		DDH_INTERNALS_T *inptr;	/// Internal pointer for allocation
	}
}

/// Internals for DDH_T
private struct DDH_INTERNALS_T
{
	union
	{
		CRC32 crc32;	/// CRC32
		CRC64ISO crc64iso;	/// CRC64ISO
		CRC64ECMA crc64ecma;	/// CRC64ECMA
		MD5 md5;	/// MD5
		RIPEMD160 ripemd160;	/// RIPEMD160
		// SHA-1
		SHA1 sha1;	/// SHA1
		// SHA-2
		SHA224 sha224;	/// SHA224
		SHA256 sha256;	/// SHA256
		SHA384 sha384;	/// SHA384
		SHA512 sha512;	/// SHA512
		// SHA-3
		SHA3_224 sha3_224;	/// SHA3_256
		SHA3_256 sha3_256;	/// SHA3_256
		SHA3_384 sha3_384;	/// SHA3_256
		SHA3_512 sha3_512;	/// SHA3_256
		// SHAKE
		SHAKE128 shake128;	/// SHA3_256
		SHAKE256 shake256;	/// SHA3_256
	}
	union
	{
		ubyte[1024] buffer;	/// Internal buffer for raw result
		ulong bufferu64;	/// Internal union type
		uint bufferu32;	/// Internal union type
	}
	char[1024] result;	/// Internal buffer for formatted result
	size_t bufferlen;	/// Internal buffer raw result size
}

/// 
struct DDH_INFO_T
{
	DDHAction action;	/// static action
	string name;	/// static name
	string basename;	/// static basename
	uint digest_size;	/// static digest_size
	func_compute fcomp;	/// static fcomp
	func_finish fdone;	/// static fdone
	func_reset freset;	/// static freset
}
/// Structure information
// I could have done a mixin template but oh well
immutable DDH_INFO_T[] struct_meta = [
	{
		DDHAction.SumCRC32,
		"CRC-32",
		"crc32",
		BITS!(32),
		&ddh_crc32_compute,
		&ddh_crc32_finish,
		&ddh_crc32_reset
	},
	{
		DDHAction.SumCRC64ISO,
		"CRC-64-ISO",
		"crc64iso",
		BITS!(64),
		&ddh_crc64iso_compute,
		&ddh_crc64iso_finish,
		&ddh_crc64iso_reset
	},
	{
		DDHAction.SumCRC64ECMA,
		"CRC-64-ECMA",
		"crc64ecma",
		BITS!(64),
		&ddh_crc64ecma_compute,
		&ddh_crc64ecma_finish,
		&ddh_crc64ecma_reset
	},
	{
		DDHAction.HashMD5,
		"MD5-128",
		"md5",
		BITS!(128),
		&ddh_md5_compute,
		&ddh_md5_finish,
		&ddh_md5_reset
	},
	{
		DDHAction.HashRIPEMD160,
		"RIPEMD-160",
		"ripemd160",
		BITS!(160),
		&ddh_ripemd_compute,
		&ddh_ripemd_finish,
		&ddh_ripemd_reset
	},
	{
		DDHAction.HashSHA1,
		"SHA-1-160",
		"sha1",
		BITS!(160),
		&ddh_sha1_compute,
		&ddh_sha1_finish,
		&ddh_sha1_reset
	},
	{
		DDHAction.HashSHA224,
		"SHA-2-224",
		"sha224",
		BITS!(224),
		&ddh_sha224_compute,
		&ddh_sha224_finish,
		&ddh_sha224_reset
	},
	{
		DDHAction.HashSHA256,
		"SHA-2-256",
		"sha256",
		BITS!(256),
		&ddh_sha256_compute,
		&ddh_sha256_finish,
		&ddh_sha256_reset
	},
	{
		DDHAction.HashSHA384,
		"SHA-2-384",
		"sha384",
		BITS!(384),
		&ddh_sha384_compute,
		&ddh_sha384_finish,
		&ddh_sha384_reset
	},
	{
		DDHAction.HashSHA512,
		"SHA-2-512",
		"sha512",
		BITS!(512),
		&ddh_sha512_compute,
		&ddh_sha512_finish,
		&ddh_sha512_reset
	},
	{
		DDHAction.HashSHA3_224,
		"SHA-3-224",
		"sha3-224",
		BITS!(224),
		&ddh_sha3_224_compute,
		&ddh_sha3_224_finish,
		&ddh_sha3_224_reset
	},
	{
		DDHAction.HashSHA3_256,
		"SHA-3-256",
		"sha3-256",
		BITS!(256),
		&ddh_sha3_256_compute,
		&ddh_sha3_256_finish,
		&ddh_sha3_256_reset
	},
	{
		DDHAction.HashSHA3_384,
		"SHA-3-384",
		"sha3-384",
		BITS!(384),
		&ddh_sha3_384_compute,
		&ddh_sha3_384_finish,
		&ddh_sha3_384_reset
	},
	{
		DDHAction.HashSHA3_512,
		"SHA-3-512",
		"sha3-512",
		BITS!(512),
		&ddh_sha3_512_compute,
		&ddh_sha3_512_finish,
		&ddh_sha3_512_reset
	},
	{
		DDHAction.HashSHAKE128,
		"SHAKE-128",
		"shake128",
		BITS!(128),
		&ddh_shake128_compute,
		&ddh_shake128_finish,
		&ddh_shake128_reset
	},
	{
		DDHAction.HashSHAKE256,
		"SHAKE-256",
		"shake256",
		BITS!(256),
		&ddh_shake256_compute,
		&ddh_shake256_finish,
		&ddh_shake256_reset
	}
];
static assert(struct_meta.length == DDHAction.max + 1);
static foreach (i, DDH_INFO_T info; struct_meta)
{
	static assert(info.action == cast(DDHAction)i);
}

// Helps converting bits to byte sizes, avoids errors
private template BITS(int n) if (n % 8 == 0) { enum { BITS = n >> 3 } }
/// BITS test
unittest { static assert(BITS!(32) == 4); }

/// Initiates a DDH_T structure with an DDHAction value.
/// Params:
/// 	ddh = DDH_T structure
/// 	action = DDHAction value
/// Returns: True on error
bool ddh_init(ref DDH_T ddh, DDHAction action)
{
	import core.stdc.stdlib : malloc;
	
	ddh.voidptr = malloc(DDH_INTERNALS_T.sizeof);
	if (ddh.voidptr == null)
		return true;
	
	size_t i = ddh.action = action;
	ddh.compute = struct_meta[i].fcomp;
	ddh.finish  = struct_meta[i].fdone;
	ddh.reset   = struct_meta[i].freset;
	ddh.inptr.bufferlen = struct_meta[i].digest_size;
	
	ddh_reset(ddh);
	
	return false;
}

/// Get the digest size in bytes
/// Returns: Digest size
uint ddh_digest_size(ref DDH_T ddh)
{
	return struct_meta[ddh.action].digest_size;
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
/// Params: dd = DDH_T structure
/// Returns: Formatted digest
char[] ddh_string(ref DDH_T ddh)
{
	import std.format : sformat;
	
	ddh_finish(ddh);
	
	with (DDHAction)
	switch (ddh.action)
	{
	case SumCRC64ISO, SumCRC64ECMA:	// 64 bits
		return sformat(ddh.inptr.result, "%016x", ddh.inptr.bufferu64);
	case SumCRC32:	// 32 bits
		return sformat(ddh.inptr.result, "%08x", ddh.inptr.bufferu32);
	default:	// Of any length
		const size_t len = ddh.inptr.bufferlen;
		ubyte *tbuf = ddh.inptr.buffer.ptr;
		char  *rbuf = ddh.inptr.result.ptr;
		for (size_t i; i < len; ++i) {
			rbuf += fasthex(rbuf, tbuf[i]);
		}
		return ddh.inptr.result[0..len << 1];
	}
}

private:
extern (C):

pragma(inline, true)
size_t fasthex(char* buffer, ubyte v) nothrow pure @nogc
{
	buffer[1] = fasthexchar(v & 0xF);
	buffer[0] = fasthexchar(v >> 4);
	return 2;
}

pragma(inline, true)
char fasthexchar(ubyte v) nothrow pure @nogc @safe
{
	return cast(char)(v <= 9 ? v + 48 : v + 87);
}

//
// CRC-32
//

void ddh_crc32_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc32.put(data);
}
ubyte[] ddh_crc32_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..4] = v.crc32.finish()[];
}
void ddh_crc32_reset(DDH_INTERNALS_T *v)
{
	v.crc32.start();
}

//
// CRC-64-ISO
//

void ddh_crc64iso_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc64iso.put(data);
}
ubyte[] ddh_crc64iso_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..8] = v.crc64iso.finish()[];
}
void ddh_crc64iso_reset(DDH_INTERNALS_T *v)
{
	v.crc64iso.start();
}

//
// CRC-64-ECMA
//

void ddh_crc64ecma_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc64ecma.put(data);
}
ubyte[] ddh_crc64ecma_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..8] = v.crc64ecma.finish()[];
}
void ddh_crc64ecma_reset(DDH_INTERNALS_T *v)
{
	v.crc64ecma.start();
}

//
// MD5
//

void ddh_md5_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.md5.put(data);
}
ubyte[] ddh_md5_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..16] = v.md5.finish()[];
}
void ddh_md5_reset(DDH_INTERNALS_T *v)
{
	v.md5.start();
}

//
// RIPEMD-160
//

void ddh_ripemd_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.ripemd160.put(data);
}
ubyte[] ddh_ripemd_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..20] = v.ripemd160.finish()[];
}
void ddh_ripemd_reset(DDH_INTERNALS_T *v)
{
	v.ripemd160.start();
}

//
// SHA-1
//

void ddh_sha1_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha1.put(data);
}
ubyte[] ddh_sha1_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..20] = v.sha1.finish()[];
}
void ddh_sha1_reset(DDH_INTERNALS_T *v)
{
	v.sha1.start();
}

//
// SHA-2
//

void ddh_sha224_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha224.put(data);
}
ubyte[] ddh_sha224_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..28] = v.sha224.finish()[];
}
void ddh_sha224_reset(DDH_INTERNALS_T *v)
{
	v.sha224.start();
}

void ddh_sha256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha256.put(data);
}
ubyte[] ddh_sha256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.sha256.finish()[];
}
void ddh_sha256_reset(DDH_INTERNALS_T *v)
{
	v.sha256.start();
}

void ddh_sha384_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha384.put(data);
}
ubyte[] ddh_sha384_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..48] = v.sha384.finish()[];
}
void ddh_sha384_reset(DDH_INTERNALS_T *v)
{
	v.sha384.start();
}

void ddh_sha512_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha512.put(data);
}
ubyte[] ddh_sha512_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..64] = v.sha512.finish()[];
}
void ddh_sha512_reset(DDH_INTERNALS_T *v)
{
	v.sha512.start();
}

//
// SHA-3
//

void ddh_sha3_224_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_224.put(data);
}
ubyte[] ddh_sha3_224_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..28] = v.sha3_224.finish()[];
}
void ddh_sha3_224_reset(DDH_INTERNALS_T *v)
{
	v.sha3_224.start();
}

void ddh_sha3_256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_256.put(data);
}
ubyte[] ddh_sha3_256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.sha3_256.finish()[];
}
void ddh_sha3_256_reset(DDH_INTERNALS_T *v)
{
	v.sha3_256.start();
}

void ddh_sha3_384_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_384.put(data);
}
ubyte[] ddh_sha3_384_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..48] = v.sha3_384.finish()[];
}
void ddh_sha3_384_reset(DDH_INTERNALS_T *v)
{
	v.sha3_384.start();
}

void ddh_sha3_512_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_512.put(data);
}
ubyte[] ddh_sha3_512_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..64] = v.sha3_512.finish()[];
}
void ddh_sha3_512_reset(DDH_INTERNALS_T *v)
{
	v.sha3_512.start();
}

//
// SHAKE
//

void ddh_shake128_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.shake128.put(data);
}
ubyte[] ddh_shake128_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..16] = v.shake128.finish()[];
}
void ddh_shake128_reset(DDH_INTERNALS_T *v)
{
	v.shake128.start();
}

void ddh_shake256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.shake256.put(data);
}
ubyte[] ddh_shake256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.shake256.finish()[];
}
void ddh_shake256_reset(DDH_INTERNALS_T *v)
{
	v.shake256.start();
}

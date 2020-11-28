module ddh.ddh;

private import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc;
private import ddh.hash.sha3;

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

/// Last error code
enum DDHError
{
	None
}

/// Internals for DDH_T
struct DDH_INTERNALS_T
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

/// Main structure
struct DDH_T
{
	DDHAction action;	/// Checksum/Hash
	uint flags;	/// Low word=self, high word=cli
	uint chunksize;	/// Chunk processing size
	extern (C) void function(DDH_INTERNALS_T*, ubyte[]) compute;	/// compute function ptr
	extern (C) ubyte[] function(DDH_INTERNALS_T*) finish;	/// finish function ptr
	union
	{
		void *voidptr;	/// Void pointer for allocation
		DDH_INTERNALS_T *inptr;	/// Internal pointer for allocation
	}
}

private immutable uint[] digest_sizes = [
	BITS!(32),	// CRC32,
	BITS!(64),	// CRC64ISO,
	BITS!(64),	// CRC64ECMA,
	BITS!(128),	// MD5
	BITS!(160),	// RIPEMD160
	BITS!(160),	// SHA1
	BITS!(224),	// SHA224
	BITS!(256),	// SHA256
	BITS!(384),	// SHA384
	BITS!(512),	// SHA512
	BITS!(224),	// SHA3-224
	BITS!(256),	// SHA3-256
	BITS!(384),	// SHA3-384
	BITS!(512),	// SHA3-512
	BITS!(128),	// SHAKE128
	BITS!(256),	// SHAKE256
];

// Helps converting bits to byte sizes, to avoid errors
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
	
	ddh.action = action;
	ddh.flags = 0;
	ddh.chunksize = 64 * 1024;
	
	with (DDHAction)
	final switch (action)
	{
	case HashSHA3_512:
		ddh.inptr.sha3_512 = SHA3_512();
		ddh.compute = &ddh_sha3_512_compute;
		ddh.finish  = &ddh_sha3_512_finish;
		break;
	case HashSHA3_384:
		ddh.inptr.sha3_384 = SHA3_384();
		ddh.compute = &ddh_sha3_384_compute;
		ddh.finish  = &ddh_sha3_384_finish;
		break;
	case HashSHA3_256:
		ddh.inptr.sha3_256 = SHA3_256();
		ddh.compute = &ddh_sha3_256_compute;
		ddh.finish  = &ddh_sha3_256_finish;
		break;
	case HashSHA3_224:
		ddh.inptr.sha3_224 = SHA3_224();
		ddh.compute = &ddh_sha3_224_compute;
		ddh.finish  = &ddh_sha3_224_finish;
		break;
	case HashSHAKE256:
		ddh.inptr.shake256 = SHAKE256();
		ddh.compute = &ddh_shake256_compute;
		ddh.finish  = &ddh_shake256_finish;
		break;
	case HashSHAKE128:
		ddh.inptr.shake128 = SHAKE128();
		ddh.compute = &ddh_shake128_compute;
		ddh.finish  = &ddh_shake128_finish;
		break;
	case HashSHA512:
		ddh.inptr.sha512 = SHA512();
		ddh.compute = &ddh_sha512_compute;
		ddh.finish  = &ddh_sha512_finish;
		break;
	case HashSHA384:
		ddh.inptr.sha384 = SHA384();
		ddh.compute = &ddh_sha384_compute;
		ddh.finish  = &ddh_sha384_finish;
		break;
	case HashSHA256:
		ddh.inptr.sha256 = SHA256();
		ddh.compute = &ddh_sha256_compute;
		ddh.finish  = &ddh_sha256_finish;
		break;
	case HashSHA224:
		ddh.inptr.sha224 = SHA224();
		ddh.compute = &ddh_sha224_compute;
		ddh.finish  = &ddh_sha224_finish;
		break;
	case HashSHA1:
		ddh.inptr.sha1 = SHA1();
		ddh.compute = &ddh_sha1_compute;
		ddh.finish  = &ddh_sha1_finish;
		break;
	case HashRIPEMD160:
		ddh.inptr.ripemd160 = RIPEMD160();
		ddh.compute = &ddh_ripemd_compute;
		ddh.finish  = &ddh_ripemd_finish;
		break;
	case HashMD5:
		ddh.inptr.md5 = MD5();
		ddh.compute = &ddh_md5_compute;
		ddh.finish  = &ddh_md5_finish;
		break;
	case SumCRC64ECMA:
		ddh.inptr.crc64ecma = CRC64ECMA();
		ddh.compute = &ddh_crc64ecma_compute;
		ddh.finish  = &ddh_crc64ecma_finish;
		break;
	case SumCRC64ISO:
		ddh.inptr.crc64iso = CRC64ISO();
		ddh.compute = &ddh_crc64iso_compute;
		ddh.finish  = &ddh_crc64iso_finish;
		break;
	case SumCRC32:
		ddh.inptr.crc32 = CRC32();
		ddh.compute = &ddh_crc32_compute;
		ddh.finish  = &ddh_crc32_finish;
		break;
	}
	
	ddh.inptr.bufferlen = digest_sizes[action];
	
	return false;
}

/// Re-initiates the DDH session.
/// Params: ddh = DDH_T structure
void ddh_reinit(ref DDH_T ddh)
{
	with (DDHAction)
	final switch (ddh.action)
	{
	case HashSHA3_512:
		ddh.inptr.sha3_512.start();
		break;
	case HashSHA3_384:
		ddh.inptr.sha3_384.start();
		break;
	case HashSHA3_256:
		ddh.inptr.sha3_256.start();
		break;
	case HashSHA3_224:
		ddh.inptr.sha3_224.start();
		break;
	case HashSHAKE256:
		ddh.inptr.shake256.start();
		break;
	case HashSHAKE128:
		ddh.inptr.shake128.start();
		break;
	case HashSHA512:
		ddh.inptr.sha512.start();
		break;
	case HashSHA384:
		ddh.inptr.sha256.start();
		break;
	case HashSHA256:
		ddh.inptr.sha256.start();
		break;
	case HashSHA224:
		ddh.inptr.sha224.start();
		break;
	case HashSHA1:
		ddh.inptr.sha1.start();
		break;
	case HashRIPEMD160:
		ddh.inptr.ripemd160.start();
		break;
	case HashMD5:
		ddh.inptr.md5.start();
		break;
	case SumCRC64ECMA:
		ddh.inptr.crc64ecma.start();
		break;
	case SumCRC64ISO:
		ddh.inptr.crc64iso.start();
		break;
	case SumCRC32:
		ddh.inptr.crc32.start();
		break;
	}
}

/// Get the digest size in bytes
/// Returns: Digest size
uint ddh_digest_size(ref DDH_T ddh)
{
	return digest_sizes[ddh.action];
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

size_t fasthex(char* buffer, ubyte v) nothrow pure @nogc
{
	buffer[1] = fasthexchar(v & 0xF);
	buffer[0] = fasthexchar(v >> 4);
	return 2;
}

pragma(inline, true)
char fasthexchar(ubyte v) nothrow pure @nogc
{
	return cast(char)(v <= 9 ? v + 48 : v + 87);
}

//
// CRC
//

void ddh_crc32_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc32.put(data);
}
ubyte[] ddh_crc32_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..4] = v.crc32.finish()[];
}

void ddh_crc64iso_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc64iso.put(data);
}
void ddh_crc64ecma_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc64ecma.put(data);
}

ubyte[] ddh_crc64iso_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..8] = v.crc64iso.finish()[];
}
ubyte[] ddh_crc64ecma_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..8] = v.crc64ecma.finish()[];
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

//
// SHA-1 and SHA-2
//

void ddh_sha1_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha1.put(data);
}
ubyte[] ddh_sha1_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..20] = v.sha1.finish()[];
}

void ddh_sha224_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha224.put(data);
}
ubyte[] ddh_sha224_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..28] = v.sha224.finish()[];
}

void ddh_sha256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha256.put(data);
}
ubyte[] ddh_sha256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.sha256.finish()[];
}

void ddh_sha384_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha384.put(data);
}
ubyte[] ddh_sha384_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..48] = v.sha384.finish()[];
}

void ddh_sha512_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha512.put(data);
}
ubyte[] ddh_sha512_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..64] = v.sha512.finish()[];
}

//
// SHA3
//

void ddh_sha3_224_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_224.put(data);
}
ubyte[] ddh_sha3_224_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..28] = v.sha3_224.finish()[];
}

void ddh_sha3_256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_256.put(data);
}
ubyte[] ddh_sha3_256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.sha3_256.finish()[];
}

void ddh_sha3_384_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_384.put(data);
}
ubyte[] ddh_sha3_384_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..48] = v.sha3_384.finish()[];
}

void ddh_sha3_512_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.sha3_512.put(data);
}
ubyte[] ddh_sha3_512_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..64] = v.sha3_512.finish()[];
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

void ddh_shake256_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.shake256.put(data);
}
ubyte[] ddh_shake256_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..32] = v.shake256.finish()[];
}

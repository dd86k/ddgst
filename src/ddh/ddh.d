module ddh.ddh;

private import ddh.chksum.crc32, ddh.chksum.crc64,
	ddh.hash.md, ddh.hash.ripemd, ddh.hash.sha;
private import std.digest.sha, std.digest.md, std.digest.ripemd, std.digest.crc;

enum DDHAction
{
	SumCRC32,
	SumCRC64ISO,
	SumCRC64ECMA,
	HashMD5,
	HashRIPEMD160,
	HashSHA1,
	HashSHA256,
	HashSHA512,
}

enum DDHError
{
	None
}

struct DDH_INTERNALS_T
{
	union {
		CRC32 crc32;	/// CRC32
		CRC64ISO crc64iso;	/// CRC64ISO
		CRC64ECMA crc64ecma;	/// CRC64ECMA
		MD5 md5;	/// MD5
		RIPEMD160 ripemd160;	/// RIPEMD160
		SHA1 sha1;	/// SHA1
		SHA256 sha256;	/// SHA256
		SHA512 sha512;	/// SHA512
	}
	union
	{
		ubyte[1024] buffer;	/// Internal buffer for raw result
		ulong bufferu64;
		uint bufferu32;
	}
	char[1024] result;	/// Internal buffer for formatted result
	size_t bufferlen;	/// Internal buffer raw result size
}

struct DDH_T
{
	DDHAction action;
	void function(DDH_INTERNALS_T*, ubyte[]) compute;
	ubyte[] function(DDH_INTERNALS_T*) finish;
	union
	{
		void *invptr;
		DDH_INTERNALS_T *inptr;
	}
}


bool ddh_init(ref DDH_T ddh, DDHAction action, uint seed = 0)
{
	import core.stdc.stdlib : malloc;
	
	ddh.invptr = malloc(DDH_INTERNALS_T.sizeof);
	if (ddh.invptr == null)
		return true;
	
	ddh.action = action;
	
	with (DDHAction)
	final switch (action)
	{
	case SumCRC32:
		ddh.inptr.crc32 = CRC32();
		ddh.compute = &ddh_crc32_compute;
		ddh.finish  = &ddh_crc32_finish;
		ddh.inptr.bufferlen = 4;
		break;
	case SumCRC64ISO:
		ddh.inptr.crc64iso = CRC64ISO();
		ddh.compute = &ddh_crc64iso_compute;
		ddh.finish  = &ddh_crc64iso_finish;
		ddh.inptr.bufferlen = 8;
		break;
	case SumCRC64ECMA:
		ddh.inptr.crc64ecma = CRC64ECMA();
		ddh.compute = &ddh_crc64ecma_compute;
		ddh.finish  = &ddh_crc64ecma_finish;
		ddh.inptr.bufferlen = 8;
		break;
	case HashMD5:
		ddh.inptr.md5 = MD5();
		ddh.compute = &ddh_md5_compute;
		ddh.finish  = &ddh_md5_finish;
		ddh.inptr.bufferlen = 16;
		break;
	case HashRIPEMD160:
		ddh.inptr.ripemd160 = RIPEMD160();
		ddh.compute = &ddh_ripemd_compute;
		ddh.finish  = &ddh_ripemd_finish;
		ddh.inptr.bufferlen = 20;
		break;
	case HashSHA1:
		ddh.inptr.sha1 = SHA1();
		ddh.compute = &ddh_sha1_compute;
		ddh.finish  = &ddh_sha1_finish;
		ddh.inptr.bufferlen = 20;
		break;
	case HashSHA256:
		ddh.inptr.sha256 = SHA256();
		ddh.compute = &ddh_sha256_compute;
		ddh.finish  = &ddh_sha256_finish;
		ddh.inptr.bufferlen = 32;
		break;
	case HashSHA512:
		ddh.inptr.sha512 = SHA512();
		ddh.compute = &ddh_sha512_compute;
		ddh.finish  = &ddh_sha512_finish;
		ddh.inptr.bufferlen = 64;
		break;
	}
	
	return false;
}

void ddh_reinit(ref DDH_T ddh)
{
	with (DDHAction)
	final switch (ddh.action)
	{
	case SumCRC32:
		ddh.inptr.crc32.start();
		break;
	case SumCRC64ISO:
		ddh.inptr.crc64iso.start();
		break;
	case SumCRC64ECMA:
		ddh.inptr.crc64ecma.start();
		break;
	case HashMD5:
		ddh.inptr.md5.start();
		break;
	case HashRIPEMD160:
		ddh.inptr.ripemd160.start();
		break;
	case HashSHA1:
		ddh.inptr.sha1.start();
		break;
	case HashSHA256:
		ddh.inptr.sha256.start();
		break;
	case HashSHA512:
		ddh.inptr.sha512.start();
		break;
	}
}

void ddh_compute(ref DDH_T ddh, ubyte[] data)
{
	ddh.compute(ddh.inptr, data);
}

ubyte[] ddh_finish(ref DDH_T ddh)
{
	return ddh.finish(ddh.inptr);
}

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

private size_t fasthex(char* buffer, ubyte v)
{
	buffer[1] = fasthexchar(v & 0xF);
	buffer[0] = fasthexchar(v >> 4);
	return 2;
}

pragma(inline, true)
private char fasthexchar(ubyte v)
{
	return cast(char)(v <= 9 ? v + 48 : v + 87);
}
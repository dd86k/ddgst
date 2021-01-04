/**
 * Based on https://github.com/mjosaarinen/tiny_sha3
 *
 * Do consider giving the repo a star.
 *
 * Re-adapted, cleaned, and re-tweaked for D. The API should be similar to
 * the structures found in std.digest.
 *
 * See FIPS PUB 202 for more information.
 */
module ddh.hash.sha3;

private import core.bitop : rol, bswap;

private immutable ulong[24] K_RC = [
	0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
	0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
	0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
	0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
	0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
	0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
	0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
	0x8000000000008080, 0x0000000080000001, 0x8000000080008008
];
private immutable int[24] K_ROTC = [
	 1,  3,  6, 10, 15, 21, 28, 36, 45, 55,  2, 14,
	27, 41, 56,  8, 25, 43, 62, 18, 39, 61, 20, 44
];
private immutable int[24] K_PI = [
	10,  7, 11, 17, 18, 3,  5, 16,  8, 21, 24, 4,
	15, 23, 19, 13, 12, 2, 20, 14, 22,  9,  6, 1
];

/**
 * Template API SHA-3/SHAKE implementation using the Keccak[1600] function.
 * Supports SHA-3-224, SHA-3-256, SHA-3-384, SHA-3-512, SHAKE-128, and SHAKE-256.
 * 
 * The digestSize parameter is in bits. However, it's easier to use the SHA3_224,
 * SHA3_256, SHA3_384, SHA3_512, SHAKE128, and SHAKE256 aliases.
 */
public struct KECCAK(uint digestSize, bool shake = false)
{
	static if (shake)
		static assert(digestSize == 128 || digestSize == 256,
			"digest size must be 128 or 256 for SHAKE");
	else
		static assert(digestSize == 224 || digestSize == 256 ||
			digestSize == 384 || digestSize == 512,
			"digest size must be 224, 256, 384, or 512 bits");

	private enum {
		dgst_sz_bits  = digestSize,	/// digest size in bits
		dgst_sz_bytes = dgst_sz_bits >> 3,	/// digest size in bytes
		delim = shake ? 0x1f : 0x06,	/// delimiter when finishing
		rate = 200 - (dgst_sz_bits >> 2),	/// sponge rate
	}
	
	union {
		private ubyte[200] st;	/// state (8bit)
		private ulong[25] st64;	/// state (64bit)
		private size_t[200 / size_t.sizeof] stz; /// state (size_t)
	}
	
	static assert(st64.sizeof == st.sizeof);
	static assert(rate % size_t.sizeof == 0);
	
	private size_t pt; /// left-over pointer
	
	@safe:
	@nogc:
	pure:
	nothrow:
	
	/**
	 * Initiates the structure. Begins the SHA-3/SHAKE operation.
	 *
	 * This is better used when restarting the operation (e.g.,
	 * for a file).
	 */
	void start()
	{
		this = typeof(this).init;
	}
	
	/**
	 * Feed the algorithm with data.
	 *
	 * Also implements the $(REF isOutputRange, std,range,primitives)
	 * interface for `ubyte` and `const(ubyte)[]`.
	 */
	void put(scope const(ubyte)[] input...) @trusted
	{
		// Taken from suggestion
		// https://github.com/dlang/phobos/pull/7713#issuecomment-753695651
		size_t j = pt;
		// Process wordwise if properly aligned.
		if ((j | cast(size_t) input.ptr) % size_t.alignof == 0)
		{
			foreach (const word; (cast(size_t*) input.ptr)[0 .. input.length / size_t.sizeof])
			{
				stz.ptr[j / size_t.sizeof] ^= word;
				j += size_t.sizeof;
				if (j >= rate)
				{
					transform;
					j = 0;
				}
			}
			input = input.ptr[input.length - (input.length % size_t.sizeof) .. input.length];
		}
		// Process remainder bytewise.
		foreach (const b; input)
		{
			st.ptr[j++] ^= b;
			if (j >= rate)
			{
				transform;
				j = 0;
			}
		}
		pt = j;
	}
	
	/**
	 * Returns the finished hash. This also clears part of the state,
	 * leaving just the final digest.
	 */
	ubyte[dgst_sz_bytes] finish()
	{
		st[pt] ^= delim;
		st[rate - 1] ^= 0x80;
		transform;
		
		st[dgst_sz_bytes..$] = 0;	// Zero possible sensitive data
		return st[0..dgst_sz_bytes];
	}
	
	private:
	
	static void THETA1(ref ulong[5] bc, ref ulong[25] st64, size_t i)
	{
		bc[i] = st64[i] ^ st64[i + 5] ^ st64[i + 10] ^ st64[i + 15] ^ st64[i + 20];
	}
	
	static void THETA2(ref ulong[5] bc, ref ulong[25] st64, ref ulong t, size_t i)
	{
		t = bc[(i + 4) % 5] ^ rol(bc[(i + 1) % 5], 1);
		st64[     i] ^= t;
		st64[ 5 + i] ^= t;
		st64[10 + i] ^= t;
		st64[15 + i] ^= t;
		st64[20 + i] ^= t;
	}
	
	static void RHO(ref ulong[5] bc, ref ulong[25] st64, ref ulong t, size_t i)
	{
		int j = K_PI[i]; bc[0] = st64[j]; st64[j] = rol(t, K_ROTC[ i]); t = bc[0];
	}
	
	static void CHI(ref ulong[5] bc, ref ulong[25] st64, size_t j)
	{
		bc[0] = st64[j];
		bc[1] = st64[j + 1];
		bc[2] = st64[j + 2];
		bc[3] = st64[j + 3];
		bc[4] = st64[j + 4];

		st64[    j] ^= (~bc[1]) & bc[2];
		st64[j + 1] ^= (~bc[2]) & bc[3];
		st64[j + 2] ^= (~bc[3]) & bc[4];
		st64[j + 3] ^= (~bc[4]) & bc[0];
		st64[j + 4] ^= (~bc[0]) & bc[1];
	}
	
	pragma(inline, true)
	static void ROUND(ref ulong[5] bc, ref ulong[25] st64, size_t r)
	{
		ulong t = void;
		// Theta
		THETA1(bc, st64, 0);
		THETA1(bc, st64, 1);
		THETA1(bc, st64, 2);
		THETA1(bc, st64, 3);
		THETA1(bc, st64, 4);
		THETA2(bc, st64, t, 0);
		THETA2(bc, st64, t, 1);
		THETA2(bc, st64, t, 2);
		THETA2(bc, st64, t, 3);
		THETA2(bc, st64, t, 4);
		t = st64[1];
		// Rho
		RHO(bc, st64, t, 0);
		RHO(bc, st64, t, 1);
		RHO(bc, st64, t, 2);
		RHO(bc, st64, t, 3);
		RHO(bc, st64, t, 4);
		RHO(bc, st64, t, 5);
		RHO(bc, st64, t, 6);
		RHO(bc, st64, t, 7);
		RHO(bc, st64, t, 8);
		RHO(bc, st64, t, 9);
		RHO(bc, st64, t, 10);
		RHO(bc, st64, t, 11);
		RHO(bc, st64, t, 12);
		RHO(bc, st64, t, 13);
		RHO(bc, st64, t, 14);
		RHO(bc, st64, t, 15);
		RHO(bc, st64, t, 16);
		RHO(bc, st64, t, 17);
		RHO(bc, st64, t, 18);
		RHO(bc, st64, t, 19);
		RHO(bc, st64, t, 20);
		RHO(bc, st64, t, 21);
		RHO(bc, st64, t, 22);
		RHO(bc, st64, t, 23);
		// Chi
		CHI(bc, st64, 0);
		CHI(bc, st64, 5);
		CHI(bc, st64, 10);
		CHI(bc, st64, 15);
		CHI(bc, st64, 20);
		// Iota
		st64[0] ^= K_RC[r];
	}
	
	void transform()
	{
		ulong[5] bc = void;
		
		version (BigEndian) swap;
		
		ROUND(bc, st64,  0);
		ROUND(bc, st64,  1);
		ROUND(bc, st64,  2);
		ROUND(bc, st64,  3);
		ROUND(bc, st64,  4);
		ROUND(bc, st64,  5);
		ROUND(bc, st64,  6);
		ROUND(bc, st64,  7);
		ROUND(bc, st64,  8);
		ROUND(bc, st64,  9);
		ROUND(bc, st64, 10);
		ROUND(bc, st64, 11);
		ROUND(bc, st64, 12);
		ROUND(bc, st64, 13);
		ROUND(bc, st64, 14);
		ROUND(bc, st64, 15);
		ROUND(bc, st64, 16);
		ROUND(bc, st64, 17);
		ROUND(bc, st64, 18);
		ROUND(bc, st64, 19);
		ROUND(bc, st64, 20);
		ROUND(bc, st64, 21);
		ROUND(bc, st64, 22);
		ROUND(bc, st64, 23);
		
		version (BigEndian) swap;
	}
	
	version (BigEndian)
	void swap()
	{
		st64[0] = bswap(st64[0]);
		st64[1] = bswap(st64[1]);
		st64[2] = bswap(st64[2]);
		st64[3] = bswap(st64[3]);
		st64[4] = bswap(st64[4]);
		st64[5] = bswap(st64[5]);
		st64[6] = bswap(st64[6]);
		st64[7] = bswap(st64[7]);
		st64[8] = bswap(st64[8]);
		st64[9] = bswap(st64[9]);
		st64[10] = bswap(st64[10]);
		st64[11] = bswap(st64[11]);
		st64[12] = bswap(st64[12]);
		st64[13] = bswap(st64[13]);
		st64[14] = bswap(st64[14]);
		st64[15] = bswap(st64[15]);
		st64[16] = bswap(st64[16]);
		st64[17] = bswap(st64[17]);
		st64[18] = bswap(st64[18]);
		st64[19] = bswap(st64[19]);
		st64[20] = bswap(st64[20]);
		st64[21] = bswap(st64[21]);
		st64[22] = bswap(st64[22]);
		st64[23] = bswap(st64[23]);
	}
}

public alias SHA3_224 = KECCAK!(224);	/// Alias for SHA3-224
public alias SHA3_256 = KECCAK!(256);	/// Alias for SHA3-256
public alias SHA3_384 = KECCAK!(384);	/// Alias for SHA3-384
public alias SHA3_512 = KECCAK!(512);	/// Alias for SHA3-512
public alias SHAKE128 = KECCAK!(128, true);	/// Alias for SHAKE-128
public alias SHAKE256 = KECCAK!(256, true);	/// Alias for SHAKE-256

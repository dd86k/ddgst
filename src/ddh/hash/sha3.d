/**
 * Based on https://github.com/mjosaarinen/tiny_sha3
 *
 * Do consider giving the repo a star.
 *
 * Re-adapted, cleaned, and re-tweaked for D. The API should be similar to
 * the structures found in std.digest.
 *
 * See FIPS-202 for more information.
 */
module ddh.hash.sha3; 

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

pragma(inline, true)
private ulong ROTL64(ulong x, ulong y) @safe @nogc pure nothrow
{
	return (((x) << (y)) | ((x) >> (64 - (y))));
}

/**
 *
 */
public struct KECCACK(uint digestSize, bool shake = false)
{
	static if (shake)
		static assert(digestSize == 128 || digestSize == 256,
			"digest size must be 128 or 256 for SHAKE");
	else
		static assert(digestSize == 224 || digestSize == 256 ||
			digestSize == 384 || digestSize == 512,
			"digest size must be >224, <512, and be divisible by 8");

	private enum {
		dgst_sz_bits  = digestSize,
		dgst_sz_bytes = dgst_sz_bits >> 3,
		delim = shake ? 0x1f : 0x06,
		rate = 200 - (dgst_sz_bits >> 2),
	}
	
	union { align(1): // Playing it safe
		private ubyte[200] st;	/// state (8bit)
		private ulong[25] st64;	/// state (64bit)
	}
	static assert(st64.sizeof == st.sizeof);
	
	private size_t pt; /// left-over pointer
	
	@safe @nogc pure nothrow:
	
	/**
	 *
	 */
	void start()
	{
		this = typeof(this).init;
	}
	
	/**
	 *
	 */
	void put(scope const(ubyte)[] input...)
	{
		size_t j = pt;
		const size_t len = input.length;
		
		for (size_t i; i < len; ++i) {
			st[j++] ^= input[i];
			if (j >= rate) {
				transform;
				j = 0;
			}
		}
		
		pt = j;
	}
	
	/**
	 *
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
	
	void transform()
	{
		size_t i = void, j = void, r = void;
		ulong[5] bc = void;
		ulong t = void;
		
		version (BigEndian) swap;
		
		// Main iteration loop
		// Some loops were manually unrolled for performance reasons
		for (r = 0; r < 24; ++r) {
			// Theta
			for (i = 0; i < 5; i++)
				bc[i] = st64[i] ^ st64[i + 5] ^ st64[i + 10] ^ st64[i + 15] ^ st64[i + 20];

			for (i = 0; i < 5; i++) {
				t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
				for (j = 0; j < 25; j += 5)
					st64[j + i] ^= t;
			}

			// Rho
			t = st64[1];
			for (i = 0; i < 24; i++) {
				j = K_PI[i];
				bc[0] = st64[j];
				st64[j] = ROTL64(t, K_ROTC[i]);
				t = bc[0];
			}

			// Chi
			for (j = 0; j < 25; j += 5) {
				/*for (i = 0; i < 5; ++i)
					bc[i] = st64[j + i];*/
				bc[0] = st64[j];
				bc[1] = st64[j + 1];
				bc[2] = st64[j + 2];
				bc[3] = st64[j + 3];
				bc[4] = st64[j + 4];
				/*for (i = 0; i < 5; ++i)
					st64[j + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];*/
				st64[j]     ^= (~bc[1]) & bc[2];
				st64[j + 1] ^= (~bc[2]) & bc[3];
				st64[j + 2] ^= (~bc[3]) & bc[4];
				st64[j + 3] ^= (~bc[4]) & bc[0];
				st64[j + 4] ^= (~bc[0]) & bc[1];
			}

			// Iota
			st64[0] ^= K_RC[r];
		}
		
		version (BigEndian) swap;
	}
	
	version (BigEndian)
	pragma(inline, true)
	ulong bswap64(ulong v)
	{
		v = (v >> 32) | (v << 32);
		v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);
		return ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);
	}
	
	version (BigEndian)
	pragma(inline, true)
	void swap()
	{
		for (size_t i; i < 25; ++i)
			st64[i] = bswap64(st64[i]);
	}
}

public alias SHA3_224 = KECCACK!(224);	/// Alias for SHA3-224
public alias SHA3_256 = KECCACK!(256);	/// Alias for SHA3-256
public alias SHA3_384 = KECCACK!(384);	/// Alias for SHA3-384
public alias SHA3_512 = KECCACK!(512);	/// Alias for SHA3-512
public alias SHAKE128 = KECCACK!(128, true);	/// Alias for SHAKE-128
public alias SHAKE256 = KECCACK!(256, true);	/// Alias for SHAKE-256

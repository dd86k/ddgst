module ddh.hash.sha;

import ddh.ddh;
import std.digest.sha;

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

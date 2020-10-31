module ddh.hash.ripemd;

import ddh.ddh;
import std.digest.ripemd;

void ddh_ripemd_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.ripemd160.put(data);
}

ubyte[] ddh_ripemd_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..20] = v.ripemd160.finish()[];
}
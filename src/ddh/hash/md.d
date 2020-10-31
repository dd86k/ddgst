module ddh.hash.md;

import ddh.ddh;
import std.digest.md;

void ddh_md5_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.md5.put(data);
}

ubyte[] ddh_md5_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..16] = v.md5.finish()[];
}
module ddh.chksum.crc32;

import ddh.ddh;
import std.digest.crc;

void ddh_crc32_compute(DDH_INTERNALS_T *v, ubyte[] data)
{
	v.crc32.put(data);
}

ubyte[] ddh_crc32_finish(DDH_INTERNALS_T *v)
{
	return v.buffer[0..4] = v.crc32.finish()[];
}
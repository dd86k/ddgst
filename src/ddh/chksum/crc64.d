module ddh.chksum.crc64;

import ddh.ddh;
import std.digest.crc;

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
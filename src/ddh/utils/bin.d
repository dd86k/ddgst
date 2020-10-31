module ddh.utils.bin;

/**
 * Byte swap a 16-bit (ushort) value.
 * Params: v = 16-bit value
 * Returns: Swapped 16-bit value
 */
ushort bswap16(ushort v) {
	return cast(ushort)(v >> 8 | v << 8);
}

/**
 * Byte swap a 32-bit (uint) value.
 * Params: v = 32-bit value
 * Returns: Swapped 32-bit value
 */
uint bswap32(uint v) {
	v = (v >> 16) | (v << 16);
	return ((v & 0xFF00FF00) >> 8) | ((v & 0x00FF00FF) << 8);
}

/**
 * Byte swap a 64-bit (ulong) value.
 * Params: v = 64-bit value
 * Returns: Swapped 64-bit value
 */
ulong bswap64(ulong v) {
	v = (v >> 32) | (v << 32);
	v = ((v & 0xFFFF0000FFFF0000) >> 16) | ((v & 0x0000FFFF0000FFFF) << 16);
	return ((v & 0xFF00FF00FF00FF00) >> 8) | ((v & 0x00FF00FF00FF00FF) << 8);
}
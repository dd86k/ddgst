# ddh, Generic hasher

ddh is a generic hasher using the D standard library for the most part to
perform hashing and compute checksums.

Why? I wanted:
- Something quick and easy to verify the integrety of downloaded content;
- Something simple with only the most popular hashing algorithms used;
- A cross-platform tool, notably Windows®️ and Linux®️;
- A memory-mapped option (`--mmfile`);
- The same features accross different algorithms;
- And decently fast.

## Algorithm Availability

| Checksum or Hash | ddh | GNU coreutils | openssl [1] | crc32(1) [2] |
|---|---|---|---|---|
| BSD sum | | ✔️ (sum) | | |
| System V sum | | ✔️ (sum -s) | | |
| Ethernet CRC | | ✔️ (cksum) | | |
| MDC-2-128 | | | ✔️ | |
| CRC-32 | ✔️ | | | ✔️ |
| CRC-64-ISO | ✔️ | | |
| CRC-64-ECMA | ✔️ | | |
| MD4 | | | ✔️ | |
| MD5 | ✔️ | ✔️ (md5sum) | ✔️ | |
| SM3 | | | ✔️ | |
| RIPEMD-160 | ✔️ | | ✔️ | |
| SHA-1 | ✔️ | ✔️ (sha1sum) | ✔️ | |
| SHA-2 | ✔️ | ✔️ [3] | ✔️ | |
| SHA-3 | ✔️ | | ✔️ | |
| SHAKE | ✔️ | | ✔️ | |
| BLAKE2 | | ✔️ (b2sum) | ✔️ | |
| Whirlpool | | | ✔️ | |

[1] See `dgst` command\
[2] From the Perl Archive::ZIP package\
[3] sha224sum, sha256sum, sha384sum, sha512sum

## Feature Comparison

| Feature | ddh | GNU coreutils | openssl | crc32(1) [1] |
|---|---|---|---|---|
| Binary mode | ✔️ | ✔️ | ✔️ | ✔️ |
| Text mode | ✔️ | ✔️ | | |
| Check support | ✔️ | ✔️[2] | ✔️ | ✔️ |
| FILE support | ✔️ | ✔️ | ✔️ | ✔️ |
| Memory-mapped file support | ✔️ | | | |
| Standard Input support | ✔️ | ✔️ | ✔️ | |

[1] From the Perl Archive::ZIP package\
[2] All but cksum and sum

# Usage

To get a list of options available, use the `--help` argument.

## Standard Input (stdin)

The program, if lacking a third parameter or if a `-` parameter has been
detected, will enter in the stdin input mode. Please note that the `--mmfile`
option has no effect on this operating mode.

Standard pipe operations are supported.

To send a EOF signal:
- On UNIX-like systems:
  - `CTRL+D` must be pressed twice on the same line or;
  - `CTRL+D` must be pressed once on a new line.
- On Windows systems:
  - `CTRL+Z` on a new line followed with `RETURN` (Enter key).
    - This unfortunately sends a newline.
    - BUG: Must be done twice due to cmd internal mechanics. Piping recommended.

## Globbing (`*` vs. `'*'`)

This utility supports file globbing out of the box using `std.file.dirEntries`.

However, most UNIX-like terminals support globbing out of the box and may
behave differently than the previously mentionned function. To use the embedded
globbing mechanism, you may want to use `'*'` or `\*`. To disable embedded
globbing, use the `--` parameter.

The globbing pattern is further explained at
[dlang.org](https://dlang.org/phobos/std_path.html#.globMatch).

The default parameters used in `dirEntries` are `SpanMode.shallow` for its
spanmode (same-level directory), and `true` for following symobolic links.

Do take note that the embedded globbing subsystem includes hidden files.

For example: `src/*.{d,dd}` will match all files ending with `.d`
and `.dd` in the `src` directory, and will follow symbolic links.

## Memory-mapped Files

The mmfile mode's performance may vary on systems. Generally, file mode is
faster on Windows, and mmfile mode is faster on Linux systems.

# Compiling

Compiling requires a recent D compiler and DUB.

To compile a `debug` build with the default compiler:
```
dub build
```

Release recommendation with the LDC compiler:
```
dub build -b release-nobounds --compiler=ldc2
```
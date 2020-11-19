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

| Checksum or Hash | ddh | coreutils | Perl Archive::ZIP crc32(1) |
|---|---|---|---|
| BSD sum | | ✔️ (sum) | |
| System V sum | | ✔️ (sum -s) | |
| Ethernet CRC | | ✔️ (cksum) | |
| CRC-32 | ✔️ | | ✔️ |
| CRC-64-ISO | ✔️ | | |
| CRC-64-ECMA | ✔️ | | |
| MD5-128 | ✔️ | ✔️ (md5sum) | |
| RIPEMD-160 | ✔️ | | |
| BLAKE2 | | ✔️ (b2sum) | |
| SHA-1-160 | ✔️ | ✔️ (sha1sum) | |
| SHA-2-224 | ✔️ | ✔️ (sha224sum) | |
| SHA-2-256 | ✔️ | ✔️ (sha256sum) | |
| SHA-2-384 | ✔️ | ✔️ (sha384sum) | |
| SHA-2-512 | ✔️ | ✔️ (sha512sum) | |

## Feature Comparison

| Feature | ddh | coreutils | Perl Archive::ZIP crc32(1) |
|---|---|---|---|
| Binary mode | ✔️ | ✔️ | ✔️ |
| Text mode | | ✔️ | |
| UTF-16 translation | Planned | | |
| UTF-32 translation | Planned | | |
| Check support | | ✔️[1] | ✔️ |
| FILE support | ✔️ | ✔️ | ✔️ |
| Memory-mapped file support | ✔️ | | |
| Standard Input support | ✔️ | ✔️ | |
| Parallel processing | Planned | | |

[1] All but cksum and sum

# Usage

To get a list of options available: `--help`

## Standard Input (stdin)

The program, if lacking a third parameter or if a `-` parameter has been
detected, will enter in the stdin input mode. Please note that the `--mmfile`
option has no effect on this operating mode.

Standard pipe operations are supported.

To send a EOF signal:
- On a UNIX-like operating system:
  - `CTRL+D` must be pressed twice on the same line or;
  - `CTRL+D` must be pressed once on a new line.
- On a Windows-like operating system:
  - `CTRL+Z` on a new line followed with `RETURN` (Enter key).
    - This unfortunately sends a newline.
    - BUG: Must be done twice due to cmd internal mechanics. Piping recommended.

## Globbing (`*` vs. `'*'`)

This utility supports file globbing out of the box using `std.file.dirEntries`.

However, most UNIX-like terminals support globbing out of the box and may
behave differently than the previously mentionned function. To use the embedded
globbing mechanism, you may use `'*'` and `\*` as examples. To disable embedded
globbing, use the `--` parameter.

The globbing pattern is explained at
[dlang.org](https://dlang.org/phobos/std_path.html#.globMatch).

The default parameters used in `dirEntries` are:

| Parameter | Argument | Description |
|---|---|---|
| `path` | `baseDir(arg)` | Base directory
| `pattern` | `baseName(arg)` | Base filename |
| `mode` | `SpanMode.shallow` | Same-level directory only |
| `followSymlink` | `true` | Follows symbolic links |

For example, an `src/*.{d,dd}` argument will match all files ending with `.d`
and `.dd` in the `src` directory, and will follow symbolic links.

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
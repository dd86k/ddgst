# ddh, Generic hasher

ddh is a generic hasher available cross-platform (Windows, macOS, Linux, BSDs)
and more features than built-in OS tools.

## Feature Comparison

| Feature | ddh | GNU coreutils | openssl | crc32(1) [1] |
|---|---|---|---|---|
| Binary mode | ✔️ | ✔️ | ✔️ | ✔️ |
| Text mode | ✔️ | ✔️ | | |
| Check support | ✔️ | ✔️[2] | ✔️ | ✔️ |
| FILE support | ✔️ | ✔️ | ✔️ | ✔️ |
| Memory-mapped file support | ✔️ | | | |
| Standard Input support | ✔️ | ✔️ | ✔️ | |

- [1] From the Perl Archive::ZIP package
- [2] All but cksum and sum

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
| BLAKE3 | | ✔️ (b3sum) | | |
| Whirlpool | | | ✔️ | |

- [1] See `dgst` command
- [2] From the Perl Archive::ZIP package
- [3] sha224sum, sha256sum, sha384sum, sha512sum

# Usage

Typical usage should resemble:
```
ddh md5 -C 128K LICENSE
```
- `ddh`: Command;
- `md5`: Operate with MD-5;
- `-C 128K`: Set new input chunk size to 128 KiB for the following files;
- `LICENSE`: File to process.

With no arguments, the help page is shown.

To get a list of options available, use the `--help` argument.

## Standard Input (stdin)

To use the standard input (stdin) method, either:
- Omit the third parameter;
- Or use the `-` character.

## Globbing (`*` vs. `'*'`)

This utility supports file globbing out of the box using `std.file.dirEntries`.

However, while useful on Windows, most UNIX-like terminals support in-shell
globbing. This may behave differently than the `dirEntries` function.

To force the usage of the embedded globbing mechanism, you may want to use
`'*'` or `\*`. To disable it, use the `--` parameter.

The globbing pattern is further explained on
[dlang.org](https://dlang.org/phobos/std_path.html#.globMatch).

The default parameters used in `dirEntries` are:
- `SpanMode`: `shallow` (same-level directory);
- And `followSymlink`: `true` (follows soft symbolic links).

**NOTE**: The embedded globbing system includes hidden files.

**EXAMPLE**: A pattern such as `src/*.{d,dd}`:
- Matches `src/example.d`, `src/.dd`, and `src/file.dd`;
- But doesn't match `example.d`, `src/.ddd`, and `src/.e`;
- Basically all files ending with `.d` and `.dd` in the `src` directory, following symlinks.

## Memory-mapped Files

The mmfile mode's performance may vary on systems. Generally, file (default)
mode is faster on Windows, and mmfile mode is faster on Linux systems.

## Checking against a list

**NOTE**: BSD-style tags are not supported.

To check hashes in a list, like for example:
```
34f53abbdbc66ebdb969c5a77f0f8902  .gitignore
301dff35a1c11b231b67aaaed0e7be46  ddh
38605d99f2cd043879c401ff1fe292cf  ddh-test-library.exe
9a2fdb96ff77f4d71510b38c2f278ff6  ddh.exe
```

Simply use the `-c` option: `ddh md5 -c LIST`

# Compiling

Compiling requires a recent D compiler and DUB.

To compile a debug build with the default compiler:
```
dub build
```

Release recommendation with the LDC compiler:
```
dub build -b release-nobounds --compiler=ldc2
```

# Contributing

At the moment of writing, it's a bit messy.

```
man/      - Manual page
src/      - Source code, entry point, generic stuff
+- ddh/   - Reference implementations
```
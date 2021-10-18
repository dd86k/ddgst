# ddh, Generic hasher

ddh is a generic hasher available cross-platform (Windows, macOS, Linux, BSDs)
and comes with more features than built-in OS utilities.

## Feature Comparison

| Feature | ddh | GNU coreutils | openssl | crc32(1)[^1] |
|---|---|---|---|---|
| Binary mode | ✔️ | ✔️ | ✔️ | ✔️ |
| Text mode | ✔️ | ✔️ | | |
| Check support | ✔️ | ✔️[^2] | ✔️ | ✔️ |
| FILE support | ✔️ | ✔️ | ✔️ | ✔️ |
| GNU-style checksums | ✔️ | ✔️ | | |
| GNU-style checksums | ✔️ | ✔️ | | |
| SRI-style checksums | ✔️ | | | |
| Memory-mapped file support | ✔️ | | | |
| Standard Input support | ✔️ | ✔️ | ✔️ | |

## Algorithm Availability

| Checksum or Hash | ddh | GNU coreutils | openssl[^3] | crc32(1)[^1] |
|---|---|---|---|---|
| BSD sum | | ✔️ (sum) | | |
| System V sum | | ✔️ (sum -s) | | |
| Ethernet CRC | | ✔️ (cksum) | | |
| CRC-32 | ✔️ | | | ✔️ |
| CRC-64-ISO | ✔️ | | |
| CRC-64-ECMA | ✔️ | | |
| MD5 | ✔️ | ✔️ (md5sum) | ✔️ | |
| RIPEMD-160 | ✔️ | | ✔️ | |
| SHA-1 | ✔️ | ✔️ (sha1sum) | ✔️ | |
| SHA-2 | ✔️ | ✔️[^4] | ✔️ | |
| SHA-3 | ✔️ | | ✔️ | |
| SHAKE | ✔️ | | ✔️ | |
| BLAKE2 | | ✔️ (b2sum) | ✔️ | |
| BLAKE3 | | ✔️ (b3sum) | | |

# Usage

Typical usage looks like this: `ddh md5 LICENSE`
- `ddh`: Command;
- `md5`: Select MD-5;
- `LICENSE`: File.

With no arguments, the help page is shown.

To get a list of options available, use the `--help` argument.

To get a list of supported checksums and hashes, use the `list` command.

## Hash styles

By default, the GNU style is used:
```
$ ddh md5 LICENSE
1d267ceb3a8d8f75f1be3011ee4cbf53  LICENSE
```

To select the BSD style, use `--tag`:
```
$ ddh md5 LICENSE
MD5(LICENSE)= 1d267ceb3a8d8f75f1be3011ee4cbf53
```

To select the SRI style, use `--sri`:
```
$ ddh md5 LICENSE --sri
md5-HSZ86zqNj3XxvjAR7ky/Uw==
```

Only the GNU and BSD (tag) styles can be used in file checks.

## Standard Input (stdin)

To use the standard input (stdin) method, either:
- Omit the third parameter (e.g., `ddh md5`);
- Or use the `-` character (e.g., `ddh md5 -`).

## File Pattern Globbing (`*` vs. `'*'`)

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

The mmfile mode's performance may vary on systems. Typically, file
mode is faster on Windows, and mmfile mode is faster on Linux systems.

The default is file.

## Checking against a list

To check hashes in a list, like for example:
```
34f53abbdbc66ebdb969c5a77f0f8902  .gitignore
301dff35a1c11b231b67aaaed0e7be46  ddh
38605d99f2cd043879c401ff1fe292cf  ddh-test-library.exe
9a2fdb96ff77f4d71510b38c2f278ff6  ddh.exe
```

Simply use the `-c` option: `ddh md5 -c LIST`.

To use BSD-style tags, use option `--tag`.

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

[^1]: From the Perl Archive::ZIP package
[^2]: All but cksum and sum
[^3]: See `dgst` command
[^4]: sha224sum, sha256sum, sha384sum, sha512sum
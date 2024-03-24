# ddgst, DD's Hashing command utility

ddgst is a simple hasher available cross-platform (Windows, macOS, Linux, BSDs)
and comes with more features than built-in OS utilities.

## Feature Comparison

| Feature | ddgst | GNU coreutils | uutils/coreutils | OpenSSL [^3] |
|---|---|---|---|---|
| Check support | ✔️ | ✔️[^2] | ✔️ | ✔️ |
| GNU style hashes | ✔️ | ✔️ | ✔️[^4] | ✔️ |
| BSD style hashes | ✔️ | ✔️ | ✔️ | ✔️ |
| [SRI style hashes](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity) | ✔️ | [^5] | [^5] | [^5] |

## Algorithm Comparison

| Checksum/Hash | ddgst | GNU coreutils | uutils/coreutils | OpenSSL[^3] |
|---|---|---|---|---|
| CRC-32 | ✔️ | | | |
| CRC-64-ISO | ✔️ | | |
| CRC-64-ECMA | ✔️ | | |
| MurmurHash3 | ✔️ | | | | |
| MD5 | ✔️ | ✔️ | ✔️ | ✔️ |
| RIPEMD-160 | ✔️ | | ✔️ | ✔️ |
| SHA-1 | ✔️ | ✔️ | ✔️ | ✔️ |
| SHA-2 | ✔️ | ✔️ | ✔️ | ✔️ |
| SHA-3/SHAKE | ✔️ | | ✔️ | ✔️ |
| [BLAKE2b](https://www.blake2.net/) | ✔️ | ✔️ | ✔️[^9] | ✔️ |
| [BLAKE2s](https://www.blake2.net/) | ✔️ | | | ✔️ |
| [BLAKE3](https://github.com/BLAKE3-team/BLAKE3/) | | [^6] | ✔️[^9] | | [^8] |

## Algorithm Security

| Checksum/Hash | Type | Secure |
|---|---|---|
| CRC-32 | Checksum | ❌ |
| CRC-64-ISO | Checksum | ❌ |
| CRC-64-ECMA | Checksum | ❌ |
| Murmurhash-32 | Hash | ❌ |
| Murmurhash-128-32 | Hash | ❌ |
| Murmurhash-128-64 | Hash | ❌ |
| MD5 | Hash | ❌ |
| RIPEMD-160 | Hash | ✔️ |
| SHA-1 | Hash | ❌ |
| SHA-2 | Hash | ✔️ |
| SHA-3/SHAKE | Hash | ✔️ |
| [BLAKE2b](https://www.blake2.net/) | Hash | ✔️ |
| [BLAKE2s](https://www.blake2.net/) | Hash | ✔️ |

# Usage

Usage:
- `ddgst [options...|--autocheck] [file|--stdin]`

With no arguments, the help page is shown.

For a list of options available, use the `--help` argument.

For a list of supported checksums and hashes, use the `--hashes` switch.

## Hashing a file

The default mode is hashing files and directories using the GNU style.

Other styles include BSD (`--tag`), SRI (`--sri`), and plain (`--plain`).

GNU style:
```text
$ ddgst --md5 LICENSE
3853e2a78a247145b4aa16667736f6de  LICENSE
```

BSD style:
```text
$ ddgst --md5 --tag LICENSE
MD5(LICENSE)= 3853e2a78a247145b4aa16667736f6de
```

SRI style:
```text
$ ddgst --md5 --sri LICENSE
md5-HSZ86zqNj3XxvjAR7ky/Uw==
```

Plain:
```text
$ ddgst --md5 --plain LICENSE
1d267ceb3a8d8f75f1be3011ee4cbf53
```

## Check list using hash

todo

Check against file list:
```text
$ ddgst --sha256 -c list # Add --tag for BSD style
file1: OK
file2: FAILED
2 total: 1 mismatch, 0 not read
```

Autodetect hash:
```shell
$ ddgst --autocheck list.sha256
file: OK
file2: FAILED
2 total: 1 mismatch, 0 not read
```

## Check files against a hash digest

todo

```text
$ ddgst --sha1 LICENSE -A f6067df486cbdbb0aac026b799b26261c92734a3
LICENSE: OK
```

## Compare files against each other

todo

```text
$ ddgst --sha512 --compare LICENSE README.md dub.sdl 
Files 'LICENSE' and 'README.md' are different
Files 'README.md' and 'dub.sdl' are different
Files 'LICENSE' and 'dub.sdl' are different
```

## Hash parameters

Some hashes may take optional parameters.

- BLAKE2: The `--key` option takes a binary file for keying the hash.
- Murmurhash3: The `--seed` option takes an argument literal for seeding the hash.

# File Pattern Globbing (`*` vs. `'*'`)

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

## Errors

| Code  | Description |
|-------|---|
| 1	| CLI error |
| 2	| No hashes selected or autocheck not used |
| 3	| Internal error: Unable to initiate hash module with hash |
| 4	| Failed to set the hash key |
| 5	| Failed to set the hash seed |
| 6	| No such file |
| 7	| Could not determine hash type |
| 9	| Could not hash text argument |
| 10	| List is empty |
| 11	| Unsupported tag format in list due to missing filename |
| 12	| Internal error: Couldn't continue processing list |
| 15	| Two or more files are required to compare |

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

To compile with GDC, you'll also need gdmd installed.

[^2]: All but cksum and sum.
[^3]: See `dgst` command.
[^4]: `*` prepended to filename.
[^5]: Possible to do with a [chain of commands](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity#tools_for_generating_sri_hashes), but good luck remembering them.
[^6]: While the official BLAKE3 team has a b3sum, GNU does not.
[^8]: The OpenSSL team is waiting for BLAKE3 to be standardized.
[^9]: As of 0.0.13
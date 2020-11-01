# ddh, Generic hasher

ddh is a generic hasher using the D standard library for the most part to
perform hashing and compute checksums.

Why? I wanted:
- Something quick and easy to verify the integrety of downloaded content;
- Something simple with only the most popular hashing algorithms used;
- A cross-platform tool, notably Windows®️ and Linux®️;
- A memory-mapped option (`-mmfile`);
- And decently fast.

Supported hashes and checksums

| Common name | Technical name |
|---|---|
| `crc32` | CRC-32 |
| `crc64iso` | CRC-64-ISO |
| `crc64ecma` | CRC-64-ECMA |
| `md5` | MD5-128 |
| `ripemd160` | RIPEMD-160 |
| `sha1` | SHA-1-160 |
| `sha256` | SHA-2-256 |
| `sha512` | SHA-2-512 |

# Usage

The utility use a straightforward approach for its commandline:
```
ddh {page}
ddh {hash|checksum} [options...] [{file|-}]
```

| Option | Description |
|---|---|
| `-mmfile` | Switch input mode to mmfile for the following files |
| `-file` | Switch input mode to file for the following files |
| `-` | Switch input mode to stdin for this input entry |

## Examples

View the help page:
```
ddh help`, `ddh --help
```

Hash a file using memory-mapping with SHA-256:
```
ddh sha256 -mmfile os.iso
```

## Standard Input (stdin)

The program, if lacking a third parameter or if a `-` parameter has been
detected, will enter into the stdin input mode. Please note that the `-mmfile`
option has no effect on this operating mode.

Standard pipe operations are supported.

While typically not recommended, if the keyboard input method is used, to send
a EOF signal:
- On a UNIX-like operating system:
  - `CTRL+D` must be pressed twice on the same line or;
  - `CTRL+D` must be pressed once on a new line.
- On a Windows-like operating system:
  - `CTRL+Z` on a new line followed with `RETURN` (Enter key).
    - This unfortunately sends a newline.
    - BUG: Must be done twice due to cmd internal mechanics. Piping recommended.

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
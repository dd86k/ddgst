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
ddh {action}
ddh {hash|checksum} file [option...]
```

Examples:
- View the help page: `ddh help`, `ddh --help`
- Hash a file with SHA-256 as memory-mapped: `ddh sha256 os.iso -mfile`

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
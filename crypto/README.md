# moonbitlang/x/crypto

## Overview

A collection of cryptographic hash functions and utilities.

## Usage

> Strings in MoonBit are UTF-16 LE encoded.

### SHA-1

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(sha1(input.to_bytes()))) // bd136cb58899c93173c33a90dde95ead0d0cf6df
```

### MD5

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(md5(input.to_bytes()))) // b0986ae6ee1eefee8a4a399090126837
```

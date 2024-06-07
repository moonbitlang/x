# moonbitlang/x/crypto

## Overview

A collection of cryptographic hash functions and utilities.

## Usage

### SHA-1

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(sha1(a.to_bytes()))) // bd136cb58899c93173c33a90dde95ead0d0cf6df
```
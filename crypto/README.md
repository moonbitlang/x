# moonbitlang/x/crypto

## Overview

A collection of cryptographic hash functions and utilities.

## Usage

> Strings in MoonBit are UTF-16 LE encoded.

### SHA-1

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(sha1(input.to_bytes())))
// => bd136cb58899c93173c33a90dde95ead0d0cf6df
```

### MD5

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(md5sum(input.to_bytes())))
// => b0986ae6ee1eefee8a4a399090126837

// or buffered
let ctx = MD5Context::make()
ctx.update(b"\x61") // 'a'
ctx.update(b"\x62") // 'b'
ctx.update(b"\x63") // 'c'
println(bytes_to_hex_string(ctx.finialize())) // or `ctx.compute()`
// => ce1473cf80c6b3fda8e3dfc006adc315
```

### SM3

```moonbit
let input = "The quick brown fox jumps over the lazy dog"
println(bytes_to_hex_string(sm3sum(input.to_bytes())))
// => fc2b31896629e88652ca1e3be449ec7ec93f7e5e29769f273fb973bc1858c66d


//buffered
let ctx = SM3Context::make()
ctx.update(b"\x61") // 'a'
ctx.update(b"\x62") // 'b'
ctx.update(b"\x63") // 'c'
println(bytes_to_hex_string(ctx.finialize()))
// => 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0
```

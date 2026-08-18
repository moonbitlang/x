# moonbitlang/x/crypto

## Overview

A collection of cryptographic hash functions and utilities.

## Security

MD4, MD5, SHA-1, and RIPEMD-160 are provided for compatibility and should not
be used where collision resistance is required. Prefer SHA-256, SHA-384,
SHA-512, or SM3 for new applications.

AES-ECB, AES-CBC, and raw ChaCha encryption do not authenticate ciphertexts.
New protocols should use an authenticated-encryption construction. AES modes
also do not apply padding. ChaCha callers that need to handle exhaustion of the
32-bit block counter should use `ChaCha::transform_checked`.

## Usage

> Strings in MoonBit are UTF-16 LE encoded.

### SHA-1

```moonbit check
///|
test {
  let input = "The quick brown fox jumps over the lazy dog"
  inspect(
    bytes_to_hex_string(sha1(@encoding.encode(UTF16, input))),
    content="bd136cb58899c93173c33a90dde95ead0d0cf6df",
  )
}
```

### MD5

```moonbit check
///|
test {
  let input = "The quick brown fox jumps over the lazy dog"
  inspect(
    bytes_to_hex_string(md5(@encoding.encode(UTF16, input))),
    content="b0986ae6ee1eefee8a4a399090126837",
  )

  // buffered
  let ctx = MD5::new()
  ctx.update(b"a")
  ctx.update(b"b")
  ctx.update(b"c")
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="900150983cd24fb0d6963f7d28e17f72",
  )
}
```

### SM3

```moonbit check
///|
test {
  let input = "The quick brown fox jumps over the lazy dog"
  inspect(
    bytes_to_hex_string(sm3(@encoding.encode(UTF16, input))),
    content="fc2b31896629e88652ca1e3be449ec7ec93f7e5e29769f273fb973bc1858c66d",
  )

  //buffered
  let ctx = SM3::new()
  ctx.update(b"a".to_fixedarray())
  ctx.update(b"b".to_fixedarray())
  ctx.update(b"c".to_fixedarray())
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0",
  )
}
```

### MD4

```moonbit check
///|
test {
  inspect(
    bytes_to_hex_string(md4(b"abc")),
    content="a448017aaf21d8525fc10ae87aa6729d",
  )
}
```

### RIPEMD-160

```moonbit check
///|
test {
  inspect(
    bytes_to_hex_string(ripemd160(b"abc")),
    content="8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
  )
}
```

### SHA-512 / SHA-384

```moonbit check
///|
test {
  inspect(
    bytes_to_hex_string(sha512(b"abc")),
    content="ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
  inspect(
    bytes_to_hex_string(sha384(b"abc")),
    content="cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7",
  )
}
```

### AES

AES-128/192/256 block cipher, with ECB and CBC modes. All functions raise
`CryptoError` on invalid key, block, IV or data lengths; no padding is applied.

```moonbit check
///|
test {
  let key = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let data = b"0123456789abcdef0123456789abcdef"
  let encrypted = aes_ecb_encrypt(key, data)
  inspect(
    aes_ecb_decrypt(key, encrypted),
    content="b\"0123456789abcdef0123456789abcdef\"",
  )
}
```

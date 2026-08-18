// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn aestest_ecb(key : BytesView, data : BytesView) -> String raise CryptoError {
  bytes_to_hex_string(@crypto.aes_ecb_encrypt(key, data))
}

///|
test "aes_fips197_vectors" { // FIPS 197 Appendix C
  let pt = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  inspect(
    aestest_ecb(
      b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f", pt,
    ),
    content="69c4e0d86a7b0430d8cdb78070b4c55a",
  )
  inspect(
    aestest_ecb(
      b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17",
      pt,
    ),
    content="dda97ca4864cdfe06eaf70a0ec0d7191",
  )
  inspect(
    aestest_ecb(
      b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f",
      pt,
    ),
    content="8ea2b7ca516745bfeafc49904b496089",
  )
}

///|
test "aes ecb roundtrip (128/192/256)" {
  let data = b"0123456789abcdef0123456789abcdef"
  let key128 = b"0123456789abcdef"
  let key192 = b"0123456789abcdef01234567"
  let key256 = b"0123456789abcdef0123456789abcdef"
  let ecb128 = @crypto.aes_ecb_encrypt(key128, data)
  let ecb128_dec = @crypto.aes_ecb_decrypt(key128, ecb128)
  inspect(ecb128_dec, content="b\"0123456789abcdef0123456789abcdef\"")
  let ecb192 = @crypto.aes_ecb_encrypt(key192, data)
  let ecb192_dec = @crypto.aes_ecb_decrypt(key192, ecb192)
  inspect(ecb192_dec, content="b\"0123456789abcdef0123456789abcdef\"")
  let ecb256 = @crypto.aes_ecb_encrypt(key256, data)
  let ecb256_dec = @crypto.aes_ecb_decrypt(key256, ecb256)
  inspect(ecb256_dec, content="b\"0123456789abcdef0123456789abcdef\"")
}

///|
test "aes cbc" {
  let key = b"\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f"
  let iv = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  let data = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xaa\xbb\xcc\xdd\xee\xff"
  let enc = @crypto.aes_cbc_encrypt(key, iv, data)
  inspect(
    bytes_to_hex_string(enc),
    content="c6a13b37878f5b826f4f8162a1c8d8798d4df1c219d7c77049d4ea996ce7ae4c",
  )
  let dec = @crypto.aes_cbc_decrypt(key, iv, enc)
  inspect(
    bytes_to_hex_string(dec),
    content="00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
  )
}

///|
test "aes invalid key/iv/data lengths" {
  let key128 = b"0123456789abcdef"
  let data = b"0123456789abcdef0123456789abcdef"
  try @crypto.aes_ecb_encrypt(b"short", data) catch {
    e => inspect(e is @crypto.CryptoError::InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_ecb_encrypt to raise")
  }
  try @crypto.aes_ecb_encrypt(key128, b"123") catch {
    e => inspect(e is @crypto.CryptoError::InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_ecb_encrypt to raise")
  }
  try @crypto.aes_cbc_decrypt(key128, b"iv", data) catch {
    e => inspect(e is @crypto.CryptoError::InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_cbc_decrypt to raise")
  }
  try @crypto.aes_cbc_encrypt(key128, b"0000000000000000", b"123") catch {
    e => inspect(e is @crypto.CryptoError::InvalidCrypto(_), content="true")
  } noraise {
    _ => fail("expected aes_cbc_encrypt to raise")
  }
}

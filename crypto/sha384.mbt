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

// A SHA-384 message-digest algorithm implementation based on
// [FIPS 180-4] https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf

///|
pub fn[Data : ByteSource] sha384(data : Data) -> FixedArray[Byte] {
  let ret = FixedArray::make(48, Byte::default())
  SHA512::new_with_initial_state([
    0xcbbb9d5dc1059ed8UL, 0x629a292a367cd507UL, 0x9159015a3070dd17UL, 0x152fecd8f70e5939UL,
    0x67332667ffc00b31UL, 0x8eb44a8768581511UL, 0xdb0c2e0d64f98fa7UL, 0x47b5481dbefa4fa4UL,
  ])
  ..update(data)
  ._finalize_into(ret, size=6)
  ret
}

///|
pub fn sha384_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  let ret = FixedArray::make(48, Byte::default())
  SHA512::new_with_initial_state([
    0xcbbb9d5dc1059ed8UL, 0x629a292a367cd507UL, 0x9159015a3070dd17UL, 0x152fecd8f70e5939UL,
    0x67332667ffc00b31UL, 0x8eb44a8768581511UL, 0xdb0c2e0d64f98fa7UL, 0x47b5481dbefa4fa4UL,
  ])
  ..update_from_iter(data)
  ._finalize_into(ret, size=6)
  ret
}

///|
test {
  // Sha384
  assert_eq(
    bytes_to_hex_string(sha384(b"\x61\x62\x63".to_fixedarray())),
    "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7",
  )
  assert_eq(
    bytes_to_hex_string(sha384(b"")),
    "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b",
  )
  assert_eq(
    bytes_to_hex_string(sha384_from_iter(b"abcd".iter())),
    "1165b3406ff0b52a3d24721f785462ca2276c9f454a116c2b2ba20171a7905ea5a026682eb659c4d5f115c363aa3c79b",
  )
}

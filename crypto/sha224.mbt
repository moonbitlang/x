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
/// SHA-224 is a truncated variant of SHA-256 with a distinct initial state,
/// producing a 28-byte digest. It shares the compression core with SHA-256.
struct SHA224 {
  ctx : SHA256
}

///|
/// Instantiate a SHA-224 context with the standard initial hash value.
pub fn SHA224::new() -> SHA224 {
  SHA224::{
    ctx: SHA256::new_with_initial_state([
      0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7,
      0xbefa4fa4,
    ]),
  }
}

///|
pub fn[Data : ByteSource] SHA224::update(self : SHA224, data : Data) -> Unit {
  self.ctx.update(data)
}

///|
pub fn SHA224::update_from_iter(self : SHA224, data : Iter[Byte]) -> Unit {
  self.ctx.update_from_iter(data)
}

///|
pub fn SHA224::finalize(self : SHA224) -> FixedArray[Byte] {
  let ret = FixedArray::make(28, Byte::default())
  self.ctx._finalize_into(ret, size=7)
  ret
}

///|
pub impl CryptoHasher for SHA224 with fn update(self : SHA224, data : BytesView) -> Unit {
  self.ctx.update(data)
}

///|
pub impl CryptoHasher for SHA224 with fn size(_self : SHA224) -> Int {
  28
}

///|
pub impl CryptoHasher for SHA224 with fn block_size(_self : SHA224) -> Int {
  64
}

///|
pub impl CryptoHasher for SHA224 with fn reset(self : SHA224) -> Unit {
  self.ctx.reg[0] = 0xc1059ed8
  self.ctx.reg[1] = 0x367cd507
  self.ctx.reg[2] = 0x3070dd17
  self.ctx.reg[3] = 0xf70e5939
  self.ctx.reg[4] = 0xffc00b31
  self.ctx.reg[5] = 0x68581511
  self.ctx.reg[6] = 0x64f98fa7
  self.ctx.reg[7] = 0xbefa4fa4
  self.ctx.len = 0
  self.ctx.buf.fill(0)
  self.ctx.buf_index = 0
}

///|
pub impl CryptoHasher for SHA224 with fn finalize_into(
  self : SHA224,
  buffer : FixedArray[Byte],
  offset~ : Int,
) -> Unit {
  self.ctx._finalize_into(buffer, size=7, offset~)
}

///|
pub fn[Data : ByteSource] sha224(data : Data) -> FixedArray[Byte] {
  SHA224::new()..update(data).finalize()
}

///|
pub fn sha224_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  SHA224::new()..update_from_iter(data).finalize()
}

///|
pub extend SHA224 with CryptoHasher::{reset, finalize_into, size, block_size}

///|
test {
  // Sha224
  assert_eq(
    bytes_to_hex_string(sha224(b"\x61\x62\x63".to_fixedarray())),
    "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
  )
  assert_eq(
    bytes_to_hex_string(
      sha224(
        b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64".to_fixedarray(),
      ),
    ),
    "fffd3b5e90c6fc3cb77c3d04b1f7660b16a426ef6655384e8486ae1f",
  )
}

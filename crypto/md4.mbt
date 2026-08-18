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

// An MD4 message-digest algorithm implementation based on
// [RFC1320]       https://www.ietf.org/rfc/rfc1320.txt
// Note that MD4 is considered _cryptographically broken_.
// Unless mandated, more secure alternatives should be preferred.

///|
struct MD4 {
  reg : FixedArray[UInt] // state 'a' 'b' 'c' 'd'
  mut len : UInt64
  buf : FixedArray[Byte]
  mut buf_index : Int
}

///|
pub impl CryptoHasher for MD4 with fn size(_self : MD4) -> Int {
  16
}

///|
pub impl CryptoHasher for MD4 with fn block_size(_self : MD4) -> Int {
  64
}

///|
pub impl CryptoHasher for MD4 with fn reset(self : MD4) -> Unit {
  self.reg[0] = 0x67452301
  self.reg[1] = 0xefcdab89
  self.reg[2] = 0x98badcfe
  self.reg[3] = 0x10325476
  self.len = 0
  self.buf.fill(0)
  self.buf_index = 0
}

///|
/// Instantiate an MD4 context
pub fn MD4::new() -> MD4 {
  {
    reg: [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476],
    len: 0,
    buf: FixedArray::make(64, Byte::default()),
    buf_index: 0,
  }
}

// no macros, nor inline. basic md4 functions
// three auxiliary functions
//          F(X,Y,Z) = XY v not(X) Z
//          G(X,Y,Z) = XY v XZ v YZ
//          H(X,Y,Z) = X xor Y xor Z

///|
fn MD4::f(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

///|
fn MD4::g(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x & z) | (y & z)
}

///|
fn MD4::h(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn MD4::ff(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotate_left_u(a + MD4::f(b, c, d) + x, s)
}

///|
fn MD4::gg(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotate_left_u(a + MD4::g(b, c, d) + x + 0x5a827999, s)
}

///|
fn MD4::hh(a : UInt, b : UInt, c : UInt, d : UInt, x : UInt, s : Int) -> UInt {
  rotate_left_u(a + MD4::h(b, c, d) + x + 0x6ed9eba1, s)
}

///|
#inline
fn MD4::transform(state : FixedArray[UInt], input : FixedArray[UInt]) -> Unit {
  // parse_le_u32x16_into always supplies exactly 16 words; every constant
  // word index used by the rounds below is therefore in bounds.
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]

  // Round 1
  // s[ 0..15] := { 3, 7, 11, 19, 3, 7, 11, 19, ... }
  a = MD4::ff(a, b, c, d, input.unsafe_get(0), 3)
  d = MD4::ff(d, a, b, c, input.unsafe_get(1), 7)
  c = MD4::ff(c, d, a, b, input.unsafe_get(2), 11)
  b = MD4::ff(b, c, d, a, input.unsafe_get(3), 19)
  a = MD4::ff(a, b, c, d, input.unsafe_get(4), 3)
  d = MD4::ff(d, a, b, c, input.unsafe_get(5), 7)
  c = MD4::ff(c, d, a, b, input.unsafe_get(6), 11)
  b = MD4::ff(b, c, d, a, input.unsafe_get(7), 19)
  a = MD4::ff(a, b, c, d, input.unsafe_get(8), 3)
  d = MD4::ff(d, a, b, c, input.unsafe_get(9), 7)
  c = MD4::ff(c, d, a, b, input.unsafe_get(10), 11)
  b = MD4::ff(b, c, d, a, input.unsafe_get(11), 19)
  a = MD4::ff(a, b, c, d, input.unsafe_get(12), 3)
  d = MD4::ff(d, a, b, c, input.unsafe_get(13), 7)
  c = MD4::ff(c, d, a, b, input.unsafe_get(14), 11)
  b = MD4::ff(b, c, d, a, input.unsafe_get(15), 19)

  // Round 2
  // message index := { 0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15 }
  // s[16..31] := { 3, 5, 9, 13, 3, 5, 9, 13, ... }
  a = MD4::gg(a, b, c, d, input.unsafe_get(0), 3)
  d = MD4::gg(d, a, b, c, input.unsafe_get(4), 5)
  c = MD4::gg(c, d, a, b, input.unsafe_get(8), 9)
  b = MD4::gg(b, c, d, a, input.unsafe_get(12), 13)
  a = MD4::gg(a, b, c, d, input.unsafe_get(1), 3)
  d = MD4::gg(d, a, b, c, input.unsafe_get(5), 5)
  c = MD4::gg(c, d, a, b, input.unsafe_get(9), 9)
  b = MD4::gg(b, c, d, a, input.unsafe_get(13), 13)
  a = MD4::gg(a, b, c, d, input.unsafe_get(2), 3)
  d = MD4::gg(d, a, b, c, input.unsafe_get(6), 5)
  c = MD4::gg(c, d, a, b, input.unsafe_get(10), 9)
  b = MD4::gg(b, c, d, a, input.unsafe_get(14), 13)
  a = MD4::gg(a, b, c, d, input.unsafe_get(3), 3)
  d = MD4::gg(d, a, b, c, input.unsafe_get(7), 5)
  c = MD4::gg(c, d, a, b, input.unsafe_get(11), 9)
  b = MD4::gg(b, c, d, a, input.unsafe_get(15), 13)

  // Round 3
  // message index := { 0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15 }
  // s[32..47] := { 3, 9, 11, 15, 3, 9, 11, 15, ... }
  a = MD4::hh(a, b, c, d, input.unsafe_get(0), 3)
  d = MD4::hh(d, a, b, c, input.unsafe_get(8), 9)
  c = MD4::hh(c, d, a, b, input.unsafe_get(4), 11)
  b = MD4::hh(b, c, d, a, input.unsafe_get(12), 15)
  a = MD4::hh(a, b, c, d, input.unsafe_get(2), 3)
  d = MD4::hh(d, a, b, c, input.unsafe_get(10), 9)
  c = MD4::hh(c, d, a, b, input.unsafe_get(6), 11)
  b = MD4::hh(b, c, d, a, input.unsafe_get(14), 15)
  a = MD4::hh(a, b, c, d, input.unsafe_get(1), 3)
  d = MD4::hh(d, a, b, c, input.unsafe_get(9), 9)
  c = MD4::hh(c, d, a, b, input.unsafe_get(5), 11)
  b = MD4::hh(b, c, d, a, input.unsafe_get(13), 15)
  a = MD4::hh(a, b, c, d, input.unsafe_get(3), 3)
  d = MD4::hh(d, a, b, c, input.unsafe_get(11), 9)
  c = MD4::hh(c, d, a, b, input.unsafe_get(7), 11)
  b = MD4::hh(b, c, d, a, input.unsafe_get(15), 15)

  state[0] += a
  state[1] += b
  state[2] += c
  state[3] += d
}

///|
pub fn MD4::update_from_iter(self : MD4, data : Iter[Byte]) -> Unit {
  let input = FixedArray::make(16, 0U)
  data.each(fn(b) {
    self.buf[self.buf_index] = b
    self.buf_index += 1
    if self.buf_index == 64 {
      self.buf_index = 0
      self.len += 512UL
      parse_le_u32x16_into(self.buf, 0, input)
      MD4::transform(self.reg, input)
    }
  })
}

///|
pub impl CryptoHasher for MD4 with fn update(self : MD4, data : BytesView) -> Unit {
  self.update(data)
}

///|
/// update the state of given context from new `data`
pub fn[Data : ByteSource] MD4::update(self : MD4, data : Data) -> Unit {
  let input = FixedArray::make(16, 0U)
  let data_len = data.length()
  let mut offset = 0
  while offset < data_len {
    let min_len = @cmp.minimum(64 - self.buf_index, data_len - offset)
    data.blit_to(
      self.buf,
      len=min_len,
      src_offset=offset,
      dst_offset=self.buf_index,
    )
    self.buf_index += min_len
    if self.buf_index == 64 {
      self.len += 512UL
      self.buf_index = 0
      parse_le_u32x16_into(self.buf, 0, input)
      MD4::transform(self.reg, input)
    }
    offset += min_len
  }
}

///|
pub fn MD4::finalize(self : MD4) -> FixedArray[Byte] {
  let ret = FixedArray::make(16, Byte::default())
  self._finalize_into(ret)
  ret
}

///|
fn MD4::_finalize_into(
  self : MD4,
  buffer : FixedArray[Byte],
  offset? : Int = 0,
) -> Unit {
  // Copy data
  let data = FixedArray::make(64, Byte::default())
  let input = FixedArray::make(16, 0U)
  let mut cnt = self.buf_index
  let len = self.len + 8 * cnt.to_uint64()
  self.buf.blit_to(data, len=cnt)
  let reg = self.reg.copy()

  // Padding
  data[cnt] = b'\x80'
  cnt += 1
  if cnt > 56 {
    parse_le_u32x16_into(data, 0, input)
    MD4::transform(reg, input)
    data.fill(0)
  }
  // little-endian 64-bit bit length at bytes 56..64
  data.unsafe_set(56, len.to_byte())
  data.unsafe_set(57, (len >> 8).to_byte())
  data.unsafe_set(58, (len >> 16).to_byte())
  data.unsafe_set(59, (len >> 24).to_byte())
  data.unsafe_set(60, (len >> 32).to_byte())
  data.unsafe_set(61, (len >> 40).to_byte())
  data.unsafe_set(62, (len >> 48).to_byte())
  data.unsafe_set(63, (len >> 56).to_byte())
  parse_le_u32x16_into(data, 0, input)
  MD4::transform(reg, input)

  // Write result to buffer
  arr_u32_to_u8le_into(reg.iter(), buffer, offset)
}

///|
pub impl CryptoHasher for MD4 with fn finalize_into(
  self : MD4,
  buffer : FixedArray[Byte],
  offset~ : Int,
) -> Unit {
  self._finalize_into(buffer, offset~)
}

///|
/// Compute the MD4 digest of some `data` based on [RFC1320](https://www.ietf.org/rfc/rfc1320.txt).
/// - Note that MD4 is considered _cryptographically broken_.
/// Unless mandated, more secure alternatives should be preferred.
pub fn[Data : ByteSource] md4(data : Data) -> FixedArray[Byte] {
  MD4::new()..update(data).finalize()
}

///|
pub fn md4_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  MD4::new()..update_from_iter(data).finalize()
}

///|
test {
  inspect(
    bytes_to_hex_string(
      md4(
        b"\x61\x62\x63", // abc in utf-8
      ),
    ),
    content="a448017aaf21d8525fc10ae87aa6729d",
  )
  inspect(
    bytes_to_hex_string(md4(b"")),
    content="31d6cfe0d16ae931b73c59d7e0c089c0",
  )
  let hash1 = "a448017aaf21d8525fc10ae87aa6729d"
  let ctx = MD4::new()
  ctx.update(b"\x61".to_fixedarray())
  ctx.update(b"\x62".to_fixedarray())
  ctx.update(b"\x63".to_fixedarray())
  assert_eq(hash1, bytes_to_hex_string(ctx.finalize()))
  let ctx = MD4::new()
  for i = 0; i < 3; i = i + 1 {
    ctx.update_from_iter(b"\x61\x62\x63".iter())
  }
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="97cf4baebc21aa502825d9b44dd6e637",
  )
}

///|
test "md4 reentry" {
  let string = b"abcd"
  let ctx = MD4::new()
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="41decd8f579255c5200f86a4bb3ba740",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="820124ba08babea2f3bf961811f2cfd6",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="5d595c82c583af827ffa883ad86a4dab",
  )
}

///|
pub extend MD4 with CryptoHasher::{reset, finalize_into, size, block_size}

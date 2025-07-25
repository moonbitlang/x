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

// An MD5 message-digest algorithm implementation based on
// [RFC1321]       https://www.ietf.org/rfc/rfc1321.txt
// [Ron Rivest]    https://people.csail.mit.edu/rivest/Md5.c
// [md5-0.7.0]     https://docs.rs/md5/0.7.0/src/md5/lib.rs.html

///|
struct MD5Context {
  state : FixedArray[UInt] // state 'a' 'b' 'c' 'd'
  count : FixedArray[UInt]
  buffer : FixedArray[Byte]
}

///|
let padding : FixedArray[Byte] = FixedArray::make(64, Byte::default())

///| update the state of given context from new `data` 
pub fn[Data : ByteSource] MD5Context::update(
  self : MD5Context,
  data : Data,
) -> Unit {
  md5_update(self, data)
}

///| an alias of `MD5Context::compute()`
pub fn MD5Context::finalize(self : MD5Context) -> FixedArray[Byte] {
  self.md5_compute()
}

///| Instantiate a MD5 context
pub fn MD5Context::new() -> MD5Context {
  padding[0] = b'\x80'
  {
    state: [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476],
    count: [0, 0],
    buffer: FixedArray::make(64, Byte::default()),
  }
}

///| compute MD5 digest from given context
fn MD5Context::md5_compute(self : MD5Context) -> FixedArray[Byte] {
  let input = FixedArray::make(16, 0U)
  let idx = ((self.count[0] >> 3) & 0x3f).reinterpret_as_int()
  input[14] = self.count[0]
  input[15] = self.count[1]
  let bytes_slice = if idx < 56 {
    let bytes_slice = FixedArray::make(56 - idx + 1, Byte::default())
    padding.blit_to(bytes_slice, len=56 - idx + 1)
    bytes_slice
  } else {
    let bytes_slice = FixedArray::make(120 - idx + 1, Byte::default())
    padding.blit_to(bytes_slice, len=120 - idx + 1)
    bytes_slice
  }
  md5_update(self, bytes_slice)
  let mut j = 0
  for i = 0; i < 14; i = i + 1 {
    input[i] = u8_to_u32le(self.buffer, i=j)
    j += 4
  }
  md5_transform(self.state, input)
  let digest = FixedArray::make(16, Byte::default())
  let mut j = 0
  // u32 to u8
  for i = 0; i < 4; i = i + 1 {
    digest[j] = (self.state[i] & 0xff).reinterpret_as_int().to_byte()
    digest[j + 1] = ((self.state[i] >> 8) & 0xff).reinterpret_as_int().to_byte()
    digest[j + 2] = ((self.state[i] >> 16) & 0xff)
      .reinterpret_as_int()
      .to_byte()
    digest[j + 3] = ((self.state[i] >> 24) & 0xff)
      .reinterpret_as_int()
      .to_byte()
    j += 4
  }
  digest
}

// no macros, nor inline. basic md5 functions
// four auxiliary functions
//          F(X,Y,Z) = XY v not(X) Z
//          G(X,Y,Z) = XZ v Y not(Z)
//          H(X,Y,Z) = X xor Y xor Z
//          I(X,Y,Z) = Y xor (X v not(Z))

///|
fn MD5Context::f(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

///|
fn MD5Context::g(x : UInt, y : UInt, z : UInt) -> UInt {
  ((x ^ y) & z) ^ y
}

///|
fn MD5Context::h(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn MD5Context::i(x : UInt, y : UInt, z : UInt) -> UInt {
  y ^ (x | z.lnot())
}

///|
fn[Data : ByteSource] md5_update(ctx : MD5Context, data : Data) -> Unit {
  let input = FixedArray::make(16, 0U)
  let mut idx = ((ctx.count[0] >> 3) & 0x3f).reinterpret_as_int()
  let length = data.length()
  let mod_length = length.reinterpret_as_uint() << 3
  ctx.count[0] += mod_length
  if ctx.count[0] < mod_length {
    ctx.count[1] += 1
  }
  ctx.count[1] += length.reinterpret_as_uint() >> 29
  for i = 0; i < length; i = i + 1 {
    ctx.buffer[idx] = data[i]
    idx += 1
    if idx == 0x40 {
      let mut j = 0
      for k = 0; k < 16; k = k + 1 {
        input[k] = u8_to_u32le(ctx.buffer, i=j)
        j += 4
      }
      md5_transform(ctx.state, input)
      idx = 0
    }
  }
}

///|
fn md5_transform(state : FixedArray[UInt], input : FixedArray[UInt]) -> Unit {
  let mut a = state[0]
  let mut b = state[1]
  let mut c = state[2]
  let mut d = state[3]

  // Round 1
  // s[ 0..15] := { 7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22,  7, 12, 17, 22 }
  a = b + rotate_left_u(a + MD5Context::f(b, c, d) + input[0] + 0xd76aa478, 7)
  d = a + rotate_left_u(d + MD5Context::f(a, b, c) + input[1] + 0xe8c7b756, 12)
  c = d + rotate_left_u(c + MD5Context::f(d, a, b) + input[2] + 0x242070db, 17)
  b = c + rotate_left_u(b + MD5Context::f(c, d, a) + input[3] + 0xc1bdceee, 22)
  a = b + rotate_left_u(a + MD5Context::f(b, c, d) + input[4] + 0xf57c0faf, 7)
  d = a + rotate_left_u(d + MD5Context::f(a, b, c) + input[5] + 0x4787c62a, 12)
  c = d + rotate_left_u(c + MD5Context::f(d, a, b) + input[6] + 0xa8304613, 17)
  b = c + rotate_left_u(b + MD5Context::f(c, d, a) + input[7] + 0xfd469501, 22)
  a = b + rotate_left_u(a + MD5Context::f(b, c, d) + input[8] + 0x698098d8, 7)
  d = a + rotate_left_u(d + MD5Context::f(a, b, c) + input[9] + 0x8b44f7af, 12)
  c = d + rotate_left_u(c + MD5Context::f(d, a, b) + input[10] + 0xffff5bb1, 17)
  b = c + rotate_left_u(b + MD5Context::f(c, d, a) + input[11] + 0x895cd7be, 22)
  a = b + rotate_left_u(a + MD5Context::f(b, c, d) + input[12] + 0x6b901122, 7)
  d = a + rotate_left_u(d + MD5Context::f(a, b, c) + input[13] + 0xfd987193, 12)
  c = d + rotate_left_u(c + MD5Context::f(d, a, b) + input[14] + 0xa679438e, 17)
  b = c + rotate_left_u(b + MD5Context::f(c, d, a) + input[15] + 0x49b40821, 22)

  // Round 2
  // s[16..31] := { 5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20,  5,  9, 14, 20 }
  a = b + rotate_left_u(a + MD5Context::g(b, c, d) + input[1] + 0xf61e2562, 5)
  d = a + rotate_left_u(d + MD5Context::g(a, b, c) + input[6] + 0xc040b340, 9)
  c = d + rotate_left_u(c + MD5Context::g(d, a, b) + input[11] + 0x265e5a51, 14)
  b = c + rotate_left_u(b + MD5Context::g(c, d, a) + input[0] + 0xe9b6c7aa, 20)
  a = b + rotate_left_u(a + MD5Context::g(b, c, d) + input[5] + 0xd62f105d, 5)
  d = a + rotate_left_u(d + MD5Context::g(a, b, c) + input[10] + 0x02441453, 9)
  c = d + rotate_left_u(c + MD5Context::g(d, a, b) + input[15] + 0xd8a1e681, 14)
  b = c + rotate_left_u(b + MD5Context::g(c, d, a) + input[4] + 0xe7d3fbc8, 20)
  a = b + rotate_left_u(a + MD5Context::g(b, c, d) + input[9] + 0x21e1cde6, 5)
  d = a + rotate_left_u(d + MD5Context::g(a, b, c) + input[14] + 0xc33707d6, 9)
  c = d + rotate_left_u(c + MD5Context::g(d, a, b) + input[3] + 0xf4d50d87, 14)
  b = c + rotate_left_u(b + MD5Context::g(c, d, a) + input[8] + 0x455a14ed, 20)
  a = b + rotate_left_u(a + MD5Context::g(b, c, d) + input[13] + 0xa9e3e905, 5)
  d = a + rotate_left_u(d + MD5Context::g(a, b, c) + input[2] + 0xfcefa3f8, 9)
  c = d + rotate_left_u(c + MD5Context::g(d, a, b) + input[7] + 0x676f02d9, 14)
  b = c + rotate_left_u(b + MD5Context::g(c, d, a) + input[12] + 0x8d2a4c8a, 20)

  // Round 3
  // s[32..47] := { 4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23,  4, 11, 16, 23 }
  a = b + rotate_left_u(a + MD5Context::h(b, c, d) + input[5] + 0xfffa3942, 4)
  d = a + rotate_left_u(d + MD5Context::h(a, b, c) + input[8] + 0x8771f681, 11)
  c = d + rotate_left_u(c + MD5Context::h(d, a, b) + input[11] + 0x6d9d6122, 16)
  b = c + rotate_left_u(b + MD5Context::h(c, d, a) + input[14] + 0xfde5380c, 23)
  a = b + rotate_left_u(a + MD5Context::h(b, c, d) + input[1] + 0xa4beea44, 4)
  d = a + rotate_left_u(d + MD5Context::h(a, b, c) + input[4] + 0x4bdecfa9, 11)
  c = d + rotate_left_u(c + MD5Context::h(d, a, b) + input[7] + 0xf6bb4b60, 16)
  b = c + rotate_left_u(b + MD5Context::h(c, d, a) + input[10] + 0xbebfbc70, 23)
  a = b + rotate_left_u(a + MD5Context::h(b, c, d) + input[13] + 0x289b7ec6, 4)
  d = a + rotate_left_u(d + MD5Context::h(a, b, c) + input[0] + 0xeaa127fa, 11)
  c = d + rotate_left_u(c + MD5Context::h(d, a, b) + input[3] + 0xd4ef3085, 16)
  b = c + rotate_left_u(b + MD5Context::h(c, d, a) + input[6] + 0x04881d05, 23)
  a = b + rotate_left_u(a + MD5Context::h(b, c, d) + input[9] + 0xd9d4d039, 4)
  d = a + rotate_left_u(d + MD5Context::h(a, b, c) + input[12] + 0xe6db99e5, 11)
  c = d + rotate_left_u(c + MD5Context::h(d, a, b) + input[15] + 0x1fa27cf8, 16)
  b = c + rotate_left_u(b + MD5Context::h(c, d, a) + input[2] + 0xc4ac5665, 23)

  // Round 4
  // s[48..63] := { 6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21,  6, 10, 15, 21 }
  a = b + rotate_left_u(a + MD5Context::i(b, c, d) + input[0] + 0xf4292244, 6)
  d = a + rotate_left_u(d + MD5Context::i(a, b, c) + input[7] + 0x432aff97, 10)
  c = d + rotate_left_u(c + MD5Context::i(d, a, b) + input[14] + 0xab9423a7, 15)
  b = c + rotate_left_u(b + MD5Context::i(c, d, a) + input[5] + 0xfc93a039, 21)
  a = b + rotate_left_u(a + MD5Context::i(b, c, d) + input[12] + 0x655b59c3, 6)
  d = a + rotate_left_u(d + MD5Context::i(a, b, c) + input[3] + 0x8f0ccc92, 10)
  c = d + rotate_left_u(c + MD5Context::i(d, a, b) + input[10] + 0xffeff47d, 15)
  b = c + rotate_left_u(b + MD5Context::i(c, d, a) + input[1] + 0x85845dd1, 21)
  a = b + rotate_left_u(a + MD5Context::i(b, c, d) + input[8] + 0x6fa87e4f, 6)
  d = a + rotate_left_u(d + MD5Context::i(a, b, c) + input[15] + 0xfe2ce6e0, 10)
  c = d + rotate_left_u(c + MD5Context::i(d, a, b) + input[6] + 0xa3014314, 15)
  b = c + rotate_left_u(b + MD5Context::i(c, d, a) + input[13] + 0x4e0811a1, 21)
  a = b + rotate_left_u(a + MD5Context::i(b, c, d) + input[4] + 0xf7537e82, 6)
  d = a + rotate_left_u(d + MD5Context::i(a, b, c) + input[11] + 0xbd3af235, 10)
  c = d + rotate_left_u(c + MD5Context::i(d, a, b) + input[2] + 0x2ad7d2bb, 15)
  b = c + rotate_left_u(b + MD5Context::i(c, d, a) + input[9] + 0xeb86d391, 21)
  state[0] += a
  state[1] += b
  state[2] += c
  state[3] += d
}

///| Compute the MD5 digest of some `data` based on [RFC1321](https://www.ietf.org/rfc/rfc1321.txt).
/// - Note that MD5 is considered _cryptographically broken_.
/// Unless mandated, more secure alternatives should be preferred.
pub fn[Data : ByteSource] md5(data : Data) -> FixedArray[Byte] {
  let ctx = MD5Context::new()
  md5_update(ctx, data)
  ctx.md5_compute()
}

///|
test "md5_wb" {
  let hash = md5(
    "The quick brown fox jumps over the lazy dog".to_bytes().to_fixedarray(),
  )
  inspect(bytes_to_hex_string(hash), content="b0986ae6ee1eefee8a4a399090126837")
}

///|
test {
  let ctx = MD5Context::new()
  md5_update(ctx, b"\x61".to_fixedarray())
  md5_update(ctx, b"\x62".to_fixedarray())
  md5_update(ctx, b"\x63".to_fixedarray())
  let res1 = bytes_to_hex_string(ctx.md5_compute())
  let ctx = MD5Context::new()
  md5_update(ctx, b"\x61\x62\x63".to_fixedarray())
  let res2 = bytes_to_hex_string(ctx.md5_compute())
  assert_eq(res1, res2)
}

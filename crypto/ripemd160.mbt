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

// A RIPEMD-160 message-digest algorithm implementation based on
// [The RIPEMD-160 page] https://homes.esat.kuleuven.be/~bosselae/ripemd160.html
// Note that RIPEMD-160 is no longer considered a strong hash;
// unless mandated, more secure alternatives should be preferred.

///|
struct RIPEMD160 {
  reg : FixedArray[UInt] // state h0 h1 h2 h3 h4
  mut len : UInt64
  buf : FixedArray[Byte]
  mut buf_index : Int
}

///|
pub impl CryptoHasher for RIPEMD160 with fn size(_self : RIPEMD160) -> Int {
  20
}

///|
pub impl CryptoHasher for RIPEMD160 with fn block_size(_self : RIPEMD160) -> Int {
  64
}

///|
pub impl CryptoHasher for RIPEMD160 with fn reset(self : RIPEMD160) -> Unit {
  self.reg[0] = 0x67452301
  self.reg[1] = 0xefcdab89
  self.reg[2] = 0x98badcfe
  self.reg[3] = 0x10325476
  self.reg[4] = 0xc3d2e1f0
  self.len = 0
  self.buf.fill(0)
  self.buf_index = 0
}

///|
/// Instantiate a RIPEMD-160 context
pub fn RIPEMD160::new() -> RIPEMD160 {
  {
    reg: [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0],
    len: 0,
    buf: FixedArray::make(64, Byte::default()),
    buf_index: 0,
  }
}

// auxiliary functions of the left (f) and right (g) lines

///|
fn ripemd_f1(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn ripemd_f2(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x.lnot() & z)
}

///|
fn ripemd_f3(x : UInt, y : UInt, z : UInt) -> UInt {
  (x | y.lnot()) ^ z
}

///|
fn ripemd_f4(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & z) | (y & z.lnot())
}

///|
fn ripemd_f5(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ (y | z.lnot())
}

// message word selection tables of the left (r1) and right (r2) lines

///|
let ripemd_r1 : FixedArray[Int] = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 7, 4, 13, 1, 10, 6, 15, 3,
  12, 0, 9, 5, 2, 14, 11, 8, 3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
  1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2, 4, 0, 5, 9, 7, 12, 2, 10,
  14, 1, 3, 8, 11, 6, 15, 13,
]

///|
let ripemd_r2 : FixedArray[Int] = [
  5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12, 6, 11, 3, 7, 0, 13, 5, 10,
  14, 15, 8, 12, 4, 9, 1, 2, 15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
  8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14, 12, 15, 10, 4, 1, 5, 8, 7,
  6, 2, 13, 14, 0, 3, 9, 11,
]

// rotation tables of the left (s1) and right (s2) lines

///|
let ripemd_s1 : FixedArray[Int] = [
  11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8, 7, 6, 8, 13, 11, 9, 7,
  15, 7, 12, 15, 9, 11, 7, 13, 12, 11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5,
  12, 7, 5, 11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12, 9, 15, 5, 11,
  6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
]

///|
let ripemd_s2 : FixedArray[Int] = [
  8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6, 9, 13, 15, 7, 12, 8, 9,
  11, 7, 7, 12, 7, 6, 15, 13, 11, 9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13,
  7, 5, 15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8, 8, 5, 12, 9, 12,
  5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
]

// round constants of the left (k1) and right (k2) lines

///|
let ripemd_k1 : FixedArray[UInt] = [
  0x00000000, 0x5a827999, 0x6ed9eba1, 0x8f1bbcdc, 0xa953fd4e,
]

///|
let ripemd_k2 : FixedArray[UInt] = [
  0x50a28be6, 0x5c4dd124, 0x6d703ef3, 0x7a6d76e9, 0x00000000,
]

// the left line uses f1..f5 in rounds 0..4, the right line uses them in reverse

///|
fn ripemd_f_left(round : Int, x : UInt, y : UInt, z : UInt) -> UInt {
  if round == 0 {
    ripemd_f1(x, y, z)
  } else if round == 1 {
    ripemd_f2(x, y, z)
  } else if round == 2 {
    ripemd_f3(x, y, z)
  } else if round == 3 {
    ripemd_f4(x, y, z)
  } else {
    ripemd_f5(x, y, z)
  }
}

///|
fn ripemd_f_right(round : Int, x : UInt, y : UInt, z : UInt) -> UInt {
  if round == 0 {
    ripemd_f5(x, y, z)
  } else if round == 1 {
    ripemd_f4(x, y, z)
  } else if round == 2 {
    ripemd_f3(x, y, z)
  } else if round == 3 {
    ripemd_f2(x, y, z)
  } else {
    ripemd_f1(x, y, z)
  }
}

///|
#inline
fn RIPEMD160::transform(
  state : FixedArray[UInt],
  input : FixedArray[UInt],
) -> Unit {
  // parse_le_u32x16_into always supplies exactly 16 words; every table
  // word index used below is therefore in bounds.
  let mut a1 = state[0]
  let mut b1 = state[1]
  let mut c1 = state[2]
  let mut d1 = state[3]
  let mut e1 = state[4]
  let mut a2 = state[0]
  let mut b2 = state[1]
  let mut c2 = state[2]
  let mut d2 = state[3]
  let mut e2 = state[4]
  for round in 0..<5 {
    let k1 = ripemd_k1.unsafe_get(round)
    let k2 = ripemd_k2.unsafe_get(round)
    for i in 0..<16 {
      let idx = round * 16 + i
      let t1 = rotate_left_u(
          a1 +
          ripemd_f_left(round, b1, c1, d1) +
          input.unsafe_get(ripemd_r1.unsafe_get(idx)) +
          k1,
          ripemd_s1.unsafe_get(idx),
        ) +
        e1
      a1 = e1
      e1 = d1
      d1 = rotate_left_u(c1, 10)
      c1 = b1
      b1 = t1
      let t2 = rotate_left_u(
          a2 +
          ripemd_f_right(round, b2, c2, d2) +
          input.unsafe_get(ripemd_r2.unsafe_get(idx)) +
          k2,
          ripemd_s2.unsafe_get(idx),
        ) +
        e2
      a2 = e2
      e2 = d2
      d2 = rotate_left_u(c2, 10)
      c2 = b2
      b2 = t2
    }
  }
  let t = state[1] + c1 + d2
  state[1] = state[2] + d1 + e2
  state[2] = state[3] + e1 + a2
  state[3] = state[4] + a1 + b2
  state[4] = state[0] + b1 + c2
  state[0] = t
}

///|
pub fn RIPEMD160::update_from_iter(self : RIPEMD160, data : Iter[Byte]) -> Unit {
  let input = FixedArray::make(16, 0U)
  data.each(fn(b) {
    self.buf[self.buf_index] = b
    self.buf_index += 1
    if self.buf_index == 64 {
      self.buf_index = 0
      self.len += 512UL
      parse_le_u32x16_into(self.buf, 0, input)
      RIPEMD160::transform(self.reg, input)
    }
  })
}

///|
pub impl CryptoHasher for RIPEMD160 with fn update(
  self : RIPEMD160,
  data : BytesView,
) -> Unit {
  self.update(data)
}

///|
/// update the state of given context from new `data`
pub fn[Data : ByteSource] RIPEMD160::update(
  self : RIPEMD160,
  data : Data,
) -> Unit {
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
      RIPEMD160::transform(self.reg, input)
    }
    offset += min_len
  }
}

///|
pub fn RIPEMD160::finalize(self : RIPEMD160) -> FixedArray[Byte] {
  let ret = FixedArray::make(20, Byte::default())
  self._finalize_into(ret)
  ret
}

///|
fn RIPEMD160::_finalize_into(
  self : RIPEMD160,
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
    RIPEMD160::transform(reg, input)
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
  RIPEMD160::transform(reg, input)

  // Write result to buffer
  arr_u32_to_u8le_into(reg.iter(), buffer, offset)
}

///|
pub impl CryptoHasher for RIPEMD160 with fn finalize_into(
  self : RIPEMD160,
  buffer : FixedArray[Byte],
  offset~ : Int,
) -> Unit {
  self._finalize_into(buffer, offset~)
}

///|
/// Compute the RIPEMD-160 digest of some `data`.
/// - Note that RIPEMD-160 is no longer considered a strong hash;
/// unless mandated, more secure alternatives should be preferred.
pub fn[Data : ByteSource] ripemd160(data : Data) -> FixedArray[Byte] {
  RIPEMD160::new()..update(data).finalize()
}

///|
pub fn ripemd160_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  RIPEMD160::new()..update_from_iter(data).finalize()
}

///|
test {
  inspect(
    bytes_to_hex_string(
      ripemd160(
        b"\x61\x62\x63", // abc in utf-8
      ),
    ),
    content="8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
  )
  inspect(
    bytes_to_hex_string(ripemd160(b"")),
    content="9c1185a5c5e9fc54612808977ee8f548b2258d31",
  )
  let hash1 = "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
  let ctx = RIPEMD160::new()
  ctx.update(b"\x61".to_fixedarray())
  ctx.update(b"\x62".to_fixedarray())
  ctx.update(b"\x63".to_fixedarray())
  assert_eq(hash1, bytes_to_hex_string(ctx.finalize()))
  let ctx = RIPEMD160::new()
  for i = 0; i < 3; i = i + 1 {
    ctx.update_from_iter(b"\x61\x62\x63".iter())
  }
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="357caa7408a576d25c8f06853ebb1746565573b7",
  )
}

///|
test "ripemd160 reentry" {
  let string = b"abcd"
  let ctx = RIPEMD160::new()
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="2e7e536fd487deaa943fda5522d917bdb9011b7a",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="f169f36789db8960d94bbced93290098f04b10eb",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="4bcf93042b478aa5c2f41be1d179814b35a88e00",
  )
}

///|
pub extend RIPEMD160 with CryptoHasher::{reset, finalize_into, size, block_size}

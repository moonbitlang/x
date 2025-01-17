// Copyright 2024 International Digital Economy Academy
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

// A SM3 implementation based on
// - [GM/T 0004-2012]    https://www.oscca.gov.cn/sca/xxgk/2010-12/17/1002389/files/302a3ada057c4a73830536d03e683110.pdf
// SM3 is as secure as SHA256, providing similar performance. https://doi.org/10.3390/electronics8091033

///|
struct SM3Context {
  reg : FixedArray[UInt] // register A B C D E F G H. i.e. digest
  mut len : UInt64
  mut buf : FixedArray[Byte]
  mut buf_index : Int
}

///| Instantiate a SM3 context
pub fn SM3Context::new() -> SM3Context {
  {
    reg: [
      0x7380166F, 0x4914B2B9, 0x172442D7, 0xDA8A0600, 0xA96F30BC, 0x163138AA, 0xE38DEE4D,
      0xB0FB0E4E,
    ],
    len: 0,
    buf: FixedArray::make(64, 0),
    buf_index: 0,
  }
}

///|
let t : FixedArray[UInt] = [ // pre calculated
  0x79cc4519, 0xf3988a32, 0xe7311465, 0xce6228cb, 0x9cc45197, 0x3988a32f, 0x7311465e,
  0xe6228cbc, 0xcc451979, 0x988a32f3, 0x311465e7, 0x6228cbce, 0xc451979c, 0x88a32f39,
  0x11465e73, 0x228cbce6, 0x9d8a7a87, 0x3b14f50f, 0x7629ea1e, 0xec53d43c, 0xd8a7a879,
  0xb14f50f3, 0x629ea1e7, 0xc53d43ce, 0x8a7a879d, 0x14f50f3b, 0x29ea1e76, 0x53d43cec,
  0xa7a879d8, 0x4f50f3b1, 0x9ea1e762, 0x3d43cec5, 0x7a879d8a, 0xf50f3b14, 0xea1e7629,
  0xd43cec53, 0xa879d8a7, 0x50f3b14f, 0xa1e7629e, 0x43cec53d, 0x879d8a7a, 0x0f3b14f5,
  0x1e7629ea, 0x3cec53d4, 0x79d8a7a8, 0xf3b14f50, 0xe7629ea1, 0xcec53d43, 0x9d8a7a87,
  0x3b14f50f, 0x7629ea1e, 0xec53d43c, 0xd8a7a879, 0xb14f50f3, 0x629ea1e7, 0xc53d43ce,
  0x8a7a879d, 0x14f50f3b, 0x29ea1e76, 0x53d43cec, 0xa7a879d8, 0x4f50f3b1, 0x9ea1e762,
  0x3d43cec5,
]

// auxiliary functions
// FF_j = | X xor Y xor Z                       where 0 <= j <= 15
//        | (X and Y) or (X and Z) or (Y and Z) where 16 <= j <=63
///|
fn SM3Context::ff_0(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn SM3Context::ff_1(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x & z) | (y & z)
}

// GG_j = | X xor Y xor Z           where 0 <= j <= 15
//        | (X and Y) or (~X and Z) where 16 <= j <= 63
///|
fn SM3Context::gg_0(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

///|
fn SM3Context::gg_1(x : UInt, y : UInt, z : UInt) -> UInt {
  ((y ^ z) & x) ^ z // equivalent of (x & y) | (x.lnot() & z), but faster
}

// P_0 = X xor (X <<< 9) xor (X <<< 17)
// P_1 = X xor (X <<< 15) xor (X <<< 23)
///|
fn SM3Context::p_0(x : UInt) -> UInt {
  x ^ rotate_left_u(x, 9) ^ rotate_left_u(x, 17)
}

///|
fn SM3Context::p_1(x : UInt) -> UInt {
  x ^ rotate_left_u(x, 15) ^ rotate_left_u(x, 23)
}

///|
fn SM3Context::pad(self : SM3Context) -> FixedArray[Byte] {
  let mut cnt = self.buf_index
  self.len += 8UL * cnt.to_uint64()
  self.buf[cnt] = b'\x80'
  cnt += 1
  if cnt > 56 {
    let temp_arr = FixedArray::make(128, Byte::default())
    self.buf.blit_to(temp_arr, len=cnt)
    self.buf = temp_arr
  }
  while cnt % 64 != 56 {
    self.buf[cnt] = b'\x00'
    cnt += 1
  }
  self.buf[cnt] = (self.len >> 56).to_byte()
  self.buf[cnt + 1] = (self.len >> 48).to_byte()
  self.buf[cnt + 2] = (self.len >> 40).to_byte()
  self.buf[cnt + 3] = (self.len >> 32).to_byte()
  self.buf[cnt + 4] = (self.len >> 24).to_byte()
  self.buf[cnt + 5] = (self.len >> 16).to_byte()
  self.buf[cnt + 6] = (self.len >> 8).to_byte()
  self.buf[cnt + 7] = (self.len >> 0).to_byte()
  return self.buf
}

///|
fn SM3Context::transform(
  self : SM3Context,
  data : FixedArray[Byte],
  offset~ : Int = 0
) -> FixedArray[UInt] {
  let w_0 = FixedArray::make(68, 0U)
  let w_1 = FixedArray::make(64, 0U)
  let mut a = self.reg[0]
  let mut b = self.reg[1]
  let mut c = self.reg[2]
  let mut d = self.reg[3]
  let mut e = self.reg[4]
  let mut f = self.reg[5]
  let mut g = self.reg[6]
  let mut h = self.reg[7]
  for index = 0; index < 16; index = index + 1 {
    w_0[index] = bytes_u8_to_u32be(data, i=4 * index + offset)
  }
  for index = 16; index < 68; index = index + 1 {
    w_0[index] = SM3Context::p_1(
        w_0[index - 16] ^ w_0[index - 9] ^ rotate_left_u(w_0[index - 3], 15),
      ) ^
      rotate_left_u(w_0[index - 13], 7) ^
      w_0[index - 6]
  }
  for index = 0; index < 64; index = index + 1 {
    w_1[index] = w_0[index] ^ w_0[index + 4]
  }
  let mut a1 = a
  let mut b1 = b
  let mut c1 = c
  let mut d1 = d
  let mut e1 = e
  let mut f1 = f
  let mut g1 = g
  let mut h1 = h
  for index = 0; index < 16; index = index + 1 {
    let ss_1 = rotate_left_u(rotate_left_u(a1, 12) + e1 + t[index], 7)
    let ss_2 = ss_1 ^ rotate_left_u(a1, 12)
    let tt_1 = SM3Context::ff_0(a1, b1, c1) + d1 + ss_2 + w_1[index]
    let tt_2 = SM3Context::gg_0(e1, f1, g1) + h1 + ss_1 + w_0[index]
    d1 = c1
    c1 = rotate_left_u(b1, 9)
    b1 = a1
    a1 = tt_1
    h1 = g1
    g1 = rotate_left_u(f1, 19)
    f1 = e1
    e1 = SM3Context::p_0(tt_2)
  }
  for index = 16; index < 64; index = index + 1 {
    let ss_1 = rotate_left_u(rotate_left_u(a1, 12) + e1 + t[index], 7)
    let ss_2 = ss_1 ^ rotate_left_u(a1, 12)
    let tt_1 = SM3Context::ff_1(a1, b1, c1) + d1 + ss_2 + w_1[index]
    let tt_2 = SM3Context::gg_1(e1, f1, g1) + h1 + ss_1 + w_0[index]
    d1 = c1
    c1 = rotate_left_u(b1, 9)
    b1 = a1
    a1 = tt_1
    h1 = g1
    g1 = rotate_left_u(f1, 19)
    f1 = e1
    e1 = SM3Context::p_0(tt_2)
  }
  a = a ^ a1
  b = b ^ b1
  c = c ^ c1
  d = d ^ d1
  e = e ^ e1
  f = f ^ f1
  g = g ^ g1
  h = h ^ h1
  let t_arr : FixedArray[UInt] = [a, b, c, d, e, f, g, h]
  for index = 0; index < 8; index = index + 1 {
    self.reg[index] = t_arr[index]
  }
  return t_arr
}

///|
pub fn SM3Context::update_from_iter(
  self : SM3Context,
  data : Iter[Byte]
) -> Unit {
  data.each(fn(b) {
    self.buf[self.buf_index] = b
    self.buf_index += 1
    if self.buf_index == 64 {
      self.buf_index = 0
      self.len += 512UL
      let _ = self.transform(self.buf)

    }
  })
}

///| update the state of given context from new `data` 
pub fn SM3Context::update(self : SM3Context, data : FixedArray[Byte]) -> Unit {
  let mut offset = 0
  while offset < data.length() {
    let min_len = if 64 - self.buf_index >= data.length() - offset {
      data.length() - offset
    } else {
      64 - self.buf_index
    }
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
      let _ = self.transform(self.buf)

    }
    offset += min_len
  }
}

///|
fn sm3_compute(
  self : SM3Context,
  data~ : Iter[Byte] = Iter::empty()
) -> FixedArray[UInt] {
  self.update_from_iter(data)
  let msg = self.pad()
  if msg.length() > 64 {
    let _ = self.transform(msg)
    self.transform(msg, offset=64)
  } else {
    self.transform(msg)
  }
}

///| Compute the SM3 digest from given SM3Context
pub fn SM3Context::finalize(self : SM3Context) -> FixedArray[Byte] {
  arr_u32_to_u8be(self.sm3_compute().iter(), 256)
}

///| Compute the SM3 digest in `FixedArray[Byte]` of some `data`. Note that SM3 is big-endian.
pub fn sm3(data : FixedArray[Byte]) -> FixedArray[Byte] {
  let ctx = SM3Context::new()
  let _ = ctx.update(data)
  arr_u32_to_u8be(ctx.sm3_compute().iter(), 256)
}

///|
pub fn sm3_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  let ctx = SM3Context::new()
  let _ = ctx.update_from_iter(data)
  arr_u32_to_u8be(ctx.sm3_compute().iter(), 256)
}

test {
  fn sm3_u32(data : FixedArray[Byte]) -> FixedArray[UInt] {
    let ctx = SM3Context::new()
    let _ = ctx.update(data)
    ctx.sm3_compute()
  }

  inspect!(
    uints_to_hex_string(
      sm3_u32(
        b"\x61\x62\x63".to_fixedarray(), // abc in utf-8
      ).iter(),
    ),
    content="66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0",
  )
  inspect!(
    uints_to_hex_string(
      sm3_u32(
        // abcd * 16 in utf-8
        b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64".to_fixedarray(),
      ).iter(),
    ),
    content="debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732",
  )
  assert_eq!(
    bytes_to_hex_string(sm3(b"\x61\x62\x63".to_fixedarray())),
    uints_to_hex_string(sm3_u32(b"\x61\x62\x63".to_fixedarray()).iter()),
  )
  let hash1 = "66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0"
  let ctx = SM3Context::new()
  ctx.update(b"\x61".to_fixedarray())
  ctx.update(b"\x62".to_fixedarray())
  ctx.update(b"\x63".to_fixedarray())
  assert_eq!(hash1, bytes_to_hex_string(ctx.finalize()))
  let ctx = SM3Context::new()
  let data = b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64"
  for i = 0; i < data.length(); i = i + 1 {
    ctx.update(FixedArray::make(1, data[i]))
  }
  assert_eq!(
    bytes_to_hex_string(ctx.finalize()),
    "debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732",
  )
  let ctx = SM3Context::new()
  for i = 0; i < data.length(); i = i + 4 {
    ctx.update_from_iter(b"\x61\x62\x63\x64".iter())
  }
  assert_eq!(
    bytes_to_hex_string(ctx.finalize()),
    "debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732",
  )
}

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

priv struct SM3Context {
  reg : FixedArray[UInt] // register A B C D E F G H. i.e. digest
  mut len : UInt64
  mut msg : Array[Byte]
}

fn SM3Context::make() -> SM3Context {
  {
    reg: [
      0x7380166F, 0x4914B2B9, 0x172442D7, 0xDA8A0600, 0xA96F30BC, 0x163138AA, 0xE38DEE4D,
      0xB0FB0E4E,
    ],
    len: 0,
    msg: [],
  }
}

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
fn SM3Context::ff_0(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

fn SM3Context::ff_1(x : UInt, y : UInt, z : UInt) -> UInt {
  (x & y) | (x & z) | (y & z)
}

// GG_j = | X xor Y xor Z           where 0 <= j <= 15
//        | (X and Y) or (~X and Z) where 16 <= j <= 63
fn SM3Context::gg_0(x : UInt, y : UInt, z : UInt) -> UInt {
  x ^ y ^ z
}

fn SM3Context::gg_1(x : UInt, y : UInt, z : UInt) -> UInt {
  ((y ^ z) & x) ^ z // equivalent of (x & y) | (x.lnot() & z), but faster
}

// P_0 = X xor (X <<< 9) xor (X <<< 17)
// P_1 = X xor (X <<< 15) xor (X <<< 23)
fn SM3Context::p_0(x : UInt) -> UInt {
  x ^ urotate_left(x, 9) ^ urotate_left(x, 17)
}

fn SM3Context::p_1(x : UInt) -> UInt {
  x ^ urotate_left(x, 15) ^ urotate_left(x, 23)
}

fn pad(self : SM3Context) -> Array[Byte] {
  self.msg.push(b'\x80')
  while self.msg.length() % 64 != 56 {
    self.msg.push(b'\x00')
  }
  self.msg.push(self.len.lsr(56).to_byte())
  self.msg.push(self.len.lsr(48).to_byte())
  self.msg.push(self.len.lsr(40).to_byte())
  self.msg.push(self.len.lsr(32).to_byte())
  self.msg.push(self.len.lsr(24).to_byte())
  self.msg.push(self.len.lsr(16).to_byte())
  self.msg.push(self.len.lsr(8).to_byte())
  self.msg.push(self.len.lsr(0).to_byte())
  return self.msg
}

fn update(self : SM3Context, data : Ref[Array[Byte]]) -> Array[UInt] {
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
  while data.val.length() >= 64 {
    for index = 0; index < 16; index = index + 1 {
      w_0[index] = arr_u8_to_u32be(data.val, i=4 * index)
    }
    for index = 16; index < 68; index = index + 1 {
      w_0[index] = p_1(
          w_0[index - 16] ^ w_0[index - 9] ^ urotate_left(w_0[index - 3], 15),
        ) ^ urotate_left(w_0[index - 13], 7) ^ w_0[index - 6]
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
      let ss_1 = urotate_left(urotate_left(a1, 12) + e1 + t[index], 7)
      let ss_2 = ss_1 ^ urotate_left(a1, 12)
      let tt_1 = ff_0(a1, b1, c1) + d1 + ss_2 + w_1[index]
      let tt_2 = gg_0(e1, f1, g1) + h1 + ss_1 + w_0[index]
      d1 = c1
      c1 = urotate_left(b1, 9)
      b1 = a1
      a1 = tt_1
      h1 = g1
      g1 = urotate_left(f1, 19)
      f1 = e1
      e1 = p_0(tt_2)
    }
    for index = 16; index < 64; index = index + 1 {
      let ss_1 = urotate_left(urotate_left(a1, 12) + e1 + t[index], 7)
      let ss_2 = ss_1 ^ urotate_left(a1, 12)
      let tt_1 = ff_1(a1, b1, c1) + d1 + ss_2 + w_1[index]
      let tt_2 = gg_1(e1, f1, g1) + h1 + ss_1 + w_0[index]
      d1 = c1
      c1 = urotate_left(b1, 9)
      b1 = a1
      a1 = tt_1
      h1 = g1
      g1 = urotate_left(f1, 19)
      f1 = e1
      e1 = p_0(tt_2)
    }
    a = a ^ a1
    b = b ^ b1
    c = c ^ c1
    d = d ^ d1
    e = e ^ e1
    f = f ^ f1
    g = g ^ g1
    h = h ^ h1
    let t_arr = Array::make(data.val.length() - 64, b'\x00')
    data.val.blit_to(t_arr, len=data.val.length() - 64, src_offset=64)
    data.val = t_arr
  }
  let t_arr : Array[UInt] = [a, b, c, d, e, f, g, h]
  for index = 0; index < 8; index = index + 1 {
    self.reg[index] = t_arr[index]
  }
  return t_arr
}

fn compute(self : SM3Context, data : Array[Byte]) -> Unit {
  self.len += data.length().to_int64().to_uint64() * 8UL
  let msg = self.msg + data
  let block_num = msg.length() / 64
  let len = msg.length() - block_num * 64
  let _ = self.update(Ref::new(msg))
  let new_msg = Array::make(len, b'\x00')
  msg.blit_to(new_msg, ~len, src_offset=block_num * 64)
  self.msg = new_msg
}

fn sum(self : SM3Context, ~data : Array[Byte] = []) -> Array[UInt] {
  self.compute(data)
  let msg = self.pad()
  self.update(Ref::new(msg))
}

/// Compute the SM3 digest of some `data`
pub fn sm3(data : Bytes) -> Array[UInt] {
  let bytes_data = bytes_to_byte_array(data)
  let ctx = SM3Context::make()
  let _ = ctx.compute(bytes_data)
  ctx.sum()
}

test {
  inspect!(
    uints_to_hex_string(
      sm3(
        b"\x61\x62\x63", // abc in utf-8
      ),
    ),
    content="66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0",
  )
  inspect!(
    uints_to_hex_string(
      sm3(
        // abcd * 16 in utf-8
        b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64",
      ),
    ),
    content="debe9ff92275b8a138604889c18e5a4d6fdb70e5387e5765293dcba39c0c5732",
  )
}

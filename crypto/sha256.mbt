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

///|
struct Sha256Context {
  reg : FixedArray[UInt] // register A B C D E F G H. i.e. digest
  mut len : UInt64
  mut buf : Bytes
  mut buf_index : Int
}

///| Instantiate a Sha256 context
/// `reg` is the initial hash value. Defaults to Sha256's.
pub fn Sha256Context::new(
  reg~ : FixedArray[UInt] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ]
) -> Sha256Context {
  { reg, len: 0, buf: Bytes::new(64), buf_index: 0 }
}

///|
let sha256_t : FixedArray[UInt] = [ // pre calculated
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
  0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
  0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
  0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
  0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
  0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
  0xc67178f2,
]

///|
fn pad(self : Sha256Context) -> Bytes {
  let mut cnt = self.buf_index
  self.len += 8UL * cnt.to_uint64()
  self.buf[cnt] = b'\x80'
  cnt += 1
  if cnt > 56 {
    let temp_arr = Bytes::new(128)
    temp_arr.blit(0, self.buf, 0, cnt)
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
fn transform(
  self : Sha256Context,
  data : Bytes,
  offset~ : Int = 0
) -> FixedArray[UInt] {
  let w = FixedArray::make(64, 0U)
  let mut a = self.reg[0]
  let mut b = self.reg[1]
  let mut c = self.reg[2]
  let mut d = self.reg[3]
  let mut e = self.reg[4]
  let mut f = self.reg[5]
  let mut g = self.reg[6]
  let mut h = self.reg[7]
  for index = 0; index < 16; index = index + 1 {
    w[index] = bytes_u8_to_u32be(data, i=4 * index + offset)
  }
  for index = 16; index < 64; index = index + 1 {
    let sigma_0 = rotate_right_u(w[index - 15], 7) ^
      rotate_right_u(w[index - 15], 18) ^
      (w[index - 15] >> 3)
    let sigma_1 = rotate_right_u(w[index - 2], 17) ^
      rotate_right_u(w[index - 2], 19) ^
      (w[index - 2] >> 10)
    w[index] = w[index - 16] + sigma_0 + w[index - 7] + sigma_1
  }
  for index = 0; index < 64; index = index + 1 {
    let big_sigma_1 = rotate_right_u(e, 6) ^
      rotate_right_u(e, 11) ^
      rotate_right_u(e, 25)
    let t_1 = h + big_sigma_1 + SM3Context::gg_1(e, f, g) + sha256_t[index] + w[index]
    let big_sigma_0 = rotate_right_u(a, 2) ^
      rotate_right_u(a, 13) ^
      rotate_right_u(a, 22)
    let t_2 = big_sigma_0 + SM3Context::ff_1(a, b, c)
    h = g
    g = f
    f = e
    e = d + t_1
    d = c
    c = b
    b = a
    a = t_1 + t_2
  }
  self.reg[0] += a
  self.reg[1] += b
  self.reg[2] += c
  self.reg[3] += d
  self.reg[4] += e
  self.reg[5] += f
  self.reg[6] += g
  self.reg[7] += h
  self.reg
}

///|
pub fn update_from_iter(self : Sha256Context, data : Iter[Byte]) -> Unit {
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
pub fn update(self : Sha256Context, data : Bytes) -> Unit {
  let mut offset = 0
  while offset < data.length() {
    let min_len = if 64 - self.buf_index >= data.length() - offset {
      data.length() - offset
    } else {
      64 - self.buf_index
    }
    self.buf.blit(self.buf_index, data, offset, min_len)
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
fn sha256_compute(
  self : Sha256Context,
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

///| Compute the Sha256 digest from given Sha256Context
pub fn finalize(self : Sha256Context) -> Bytes {
  arr_u32_to_u8be(self.sha256_compute().iter(), 256)
}

///| Compute the Sha256 digest in `Bytes` of some `data`. Note that Sha256 is big-endian.
pub fn sha256(data : Bytes) -> Bytes {
  let ctx = Sha256Context::new()
  let _ = ctx.update(data)
  arr_u32_to_u8be(ctx.sha256_compute().iter(), 256)
}

///|
pub fn sha256_from_iter(data : Iter[Byte]) -> Bytes {
  let ctx = Sha256Context::new()
  let _ = ctx.update_from_iter(data)
  arr_u32_to_u8be(ctx.sha256_compute().iter(), 256)
}

test {
  // Sha256
  fn sha256_u32(data : Bytes) -> FixedArray[UInt] {
    let ctx = Sha256Context::new()
    let _ = ctx.update(data)
    ctx.sha256_compute()
  }

  inspect!(
    uints_to_hex_string(
      sha256_u32(
        b"\x61\x62\x63", // abc in utf-8
      ).iter(),
    ),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  inspect!(
    uints_to_hex_string(
      sha256_u32(
        // abcd * 16 in utf-8
        b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64",
      ).iter(),
    ),
    content="625b41490b883891943c5fa54ad45d7c900b9b6e91e159334e320b1f5215a209",
  )
  assert_eq!(
    bytes_to_hex_string(sha256(b"\x61\x62\x63")),
    uints_to_hex_string(sha256_u32(b"\x61\x62\x63").iter()),
  )
  let hash1 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  let ctx = Sha256Context::new()
  ctx.update(b"\x61")
  ctx.update(b"\x62")
  ctx.update(b"\x63")
  assert_eq!(hash1, bytes_to_hex_string(ctx.finalize()))
  let ctx = Sha256Context::new()
  let data = b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64"
  for i = 0; i < data.length(); i = i + 1 {
    ctx.update(Bytes::make(1, data[i]))
  }
  assert_eq!(
    bytes_to_hex_string(ctx.finalize()),
    "625b41490b883891943c5fa54ad45d7c900b9b6e91e159334e320b1f5215a209",
  )
  let ctx = Sha256Context::new()
  for i = 0; i < data.length(); i = i + 4 {
    ctx.update_from_iter(b"\x61\x62\x63\x64".iter())
  }
  assert_eq!(
    bytes_to_hex_string(ctx.finalize()),
    "625b41490b883891943c5fa54ad45d7c900b9b6e91e159334e320b1f5215a209",
  )
}

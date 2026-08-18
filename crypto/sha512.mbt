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

// A SHA-512 message-digest algorithm implementation based on
// [FIPS 180-4] https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf

///|
struct SHA512 {
  reg : FixedArray[UInt64] // register A B C D E F G H. i.e. digest
  mut len_high : UInt64
  mut len_low : UInt64
  buf : FixedArray[Byte]
  mut buf_index : Int
}

///|
fn SHA512::new_with_initial_state(reg : FixedArray[UInt64]) -> SHA512 {
  guard! reg.length() == 8
  {
    reg,
    len_high: 0,
    len_low: 0,
    buf: FixedArray::make(128, Byte::default()),
    buf_index: 0,
  }
}

///|
/// Instantiates a SHA-512 context.
pub fn SHA512::new() -> SHA512 {
  SHA512::new_with_initial_state([
    0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL,
    0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL, 0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL,
  ])
}

///|
let sha512_t : FixedArray[UInt64] = [ // pre calculated
  0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL, 0xe9b5dba58189dbbcUL,
  0x3956c25bf348b538UL, 0x59f111f1b605d019UL, 0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL,
  0xd807aa98a3030242UL, 0x12835b0145706fbeUL, 0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL,
  0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL, 0xc19bf174cf692694UL,
  0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL, 0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL,
  0x2de92c6f592b0275UL, 0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL,
  0x983e5152ee66dfabUL, 0xa831c66d2db43210UL, 0xb00327c898fb213fUL, 0xbf597fc7beef0ee4UL,
  0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL, 0x06ca6351e003826fUL, 0x142929670a0e6e70UL,
  0x27b70a8546d22ffcUL, 0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL, 0x53380d139d95b3dfUL,
  0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL, 0x92722c851482353bUL,
  0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL, 0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL,
  0xd192e819d6ef5218UL, 0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL,
  0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL, 0x2748774cdf8eeb99UL, 0x34b0bcb5e19b48a8UL,
  0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL, 0x5b9cca4f7763e373UL, 0x682e6ff3d6b2b8a3UL,
  0x748f82ee5defb2fcUL, 0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
  0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL, 0xc67178f2e372532bUL,
  0xca273eceea26619cUL, 0xd186b8c721c0c207UL, 0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL,
  0x06f067aa72176fbaUL, 0x0a637dc5a2c898a6UL, 0x113f9804bef90daeUL, 0x1b710b35131c471bUL,
  0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL, 0x431d67c49c100d4cUL,
  0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL, 0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL,
]

// Ch(x,y,z) = (x & y) ^ (~x & z)
// Maj(x,y,z) = (x & y) ^ (x & z) ^ (y & z)

///|
fn SHA512::ch(x : UInt64, y : UInt64, z : UInt64) -> UInt64 {
  (x & y) ^ (x.lnot() & z)
}

///|
fn SHA512::maj(x : UInt64, y : UInt64, z : UInt64) -> UInt64 {
  (x & y) ^ (x & z) ^ (y & z)
}

///|
fn SHA512::transform(
  data : FixedArray[Byte],
  reg : FixedArray[UInt64],
  w : FixedArray[UInt64],
) -> Unit {
  guard! reg.length() == 8
  guard! w.length() == 16
  let mut a = reg.unsafe_get(0)
  let mut b = reg.unsafe_get(1)
  let mut c = reg.unsafe_get(2)
  let mut d = reg.unsafe_get(3)
  let mut e = reg.unsafe_get(4)
  let mut f = reg.unsafe_get(5)
  let mut g = reg.unsafe_get(6)
  let mut h = reg.unsafe_get(7)
  parse_be_u64x16_into(data, 0, w)
  for index = 0; index < 80; index = index + 1 {
    let word = if index < 16 {
      w.unsafe_get(index)
    } else {
      let sigma_0_source = w.unsafe_get((index + 1) & 15)
      let sigma_0 = rotate_right_u64(sigma_0_source, 1) ^
        rotate_right_u64(sigma_0_source, 8) ^
        (sigma_0_source >> 7)
      let sigma_1_source = w.unsafe_get((index + 14) & 15)
      let sigma_1 = rotate_right_u64(sigma_1_source, 19) ^
        rotate_right_u64(sigma_1_source, 61) ^
        (sigma_1_source >> 6)
      let slot = index & 15
      let word = w.unsafe_get(slot) +
        sigma_0 +
        w.unsafe_get((index + 9) & 15) +
        sigma_1
      w.unsafe_set(slot, word)
      word
    }
    let big_sigma_1 = rotate_right_u64(e, 14) ^
      rotate_right_u64(e, 18) ^
      rotate_right_u64(e, 41)
    let t_1 = h + big_sigma_1 + SHA512::ch(e, f, g) + sha512_t[index] + word
    let big_sigma_0 = rotate_right_u64(a, 28) ^
      rotate_right_u64(a, 34) ^
      rotate_right_u64(a, 39)
    let t_2 = big_sigma_0 + SHA512::maj(a, b, c)
    h = g
    g = f
    f = e
    e = d + t_1
    d = c
    c = b
    b = a
    a = t_1 + t_2
  }
  reg.unsafe_set(0, reg.unsafe_get(0) + a)
  reg.unsafe_set(1, reg.unsafe_get(1) + b)
  reg.unsafe_set(2, reg.unsafe_get(2) + c)
  reg.unsafe_set(3, reg.unsafe_get(3) + d)
  reg.unsafe_set(4, reg.unsafe_get(4) + e)
  reg.unsafe_set(5, reg.unsafe_get(5) + f)
  reg.unsafe_set(6, reg.unsafe_get(6) + g)
  reg.unsafe_set(7, reg.unsafe_get(7) + h)
}

///|
pub fn SHA512::update_from_iter(self : SHA512, data : Iter[Byte]) -> Unit {
  let w = FixedArray::make(16, 0UL)
  data.each(fn(b) {
    self.buf[self.buf_index] = b
    self.buf_index += 1
    if self.buf_index == 128 {
      self.buf_index = 0
      let previous_len = self.len_low
      self.len_low += 1024UL
      if self.len_low < previous_len {
        self.len_high += 1
      }
      SHA512::transform(self.buf, self.reg, w)
    }
  })
}

///|
pub impl CryptoHasher for SHA512 with fn update(self : SHA512, data : BytesView) -> Unit {
  self.update(data)
}

///|
/// update the state of given context from new `data`
pub fn[Data : ByteSource] SHA512::update(self : SHA512, data : Data) -> Unit {
  let w = FixedArray::make(16, 0UL)
  let data_len = data.length()
  let mut offset = 0
  while offset < data_len {
    let min_len = @cmp.minimum(128 - self.buf_index, data_len - offset)
    data.blit_to(
      self.buf,
      len=min_len,
      src_offset=offset,
      dst_offset=self.buf_index,
    )
    self.buf_index += min_len
    if self.buf_index == 128 {
      let previous_len = self.len_low
      self.len_low += 1024UL
      if self.len_low < previous_len {
        self.len_high += 1
      }
      self.buf_index = 0
      SHA512::transform(self.buf, self.reg, w)
    }
    offset += min_len
  }
}

///|
pub fn SHA512::finalize(self : SHA512) -> FixedArray[Byte] {
  let ret = FixedArray::make(64, Byte::default())
  self._finalize_into(ret)
  ret
}

///|
/// @param size the size of the output, defaults to 8 (i.e. 64 bytes). 6 for Sha384.
fn SHA512::_finalize_into(
  self : SHA512,
  buffer : FixedArray[Byte],
  size? : Int = 8,
  offset? : Int = 0,
) -> Unit {
  // Copy data
  let data = FixedArray::make(128, Byte::default())
  let w = FixedArray::make(16, 0UL)
  let mut cnt = self.buf_index
  let buffered_bits = cnt.to_uint64() * 8UL
  let len_low = self.len_low + buffered_bits
  let len_high = self.len_high +
    (if len_low < self.len_low { 1UL } else { 0UL })
  self.buf.blit_to(data, len=cnt)
  let reg = self.reg.copy()

  // Padding
  data[cnt] = b'\x80'
  cnt += 1
  if cnt > 112 {
    SHA512::transform(data, reg, w)
    data.fill(0)
  }
  // big-endian 128-bit bit length at bytes 112..128
  data.unsafe_set(112, (len_high >> 56).to_byte())
  data.unsafe_set(113, (len_high >> 48).to_byte())
  data.unsafe_set(114, (len_high >> 40).to_byte())
  data.unsafe_set(115, (len_high >> 32).to_byte())
  data.unsafe_set(116, (len_high >> 24).to_byte())
  data.unsafe_set(117, (len_high >> 16).to_byte())
  data.unsafe_set(118, (len_high >> 8).to_byte())
  data.unsafe_set(119, len_high.to_byte())
  data.unsafe_set(120, (len_low >> 56).to_byte())
  data.unsafe_set(121, (len_low >> 48).to_byte())
  data.unsafe_set(122, (len_low >> 40).to_byte())
  data.unsafe_set(123, (len_low >> 32).to_byte())
  data.unsafe_set(124, (len_low >> 24).to_byte())
  data.unsafe_set(125, (len_low >> 16).to_byte())
  data.unsafe_set(126, (len_low >> 8).to_byte())
  data.unsafe_set(127, len_low.to_byte())
  SHA512::transform(data, reg, w)

  // Write result to buffer
  arr_u64_to_u8be_into(reg.iter().take(size), buffer, offset)
}

///|
pub impl CryptoHasher for SHA512 with fn size(_self : SHA512) -> Int {
  64
}

///|
pub impl CryptoHasher for SHA512 with fn block_size(_self : SHA512) -> Int {
  128
}

///|
pub impl CryptoHasher for SHA512 with fn reset(self : SHA512) -> Unit {
  self.reg[0] = 0x6a09e667f3bcc908UL
  self.reg[1] = 0xbb67ae8584caa73bUL
  self.reg[2] = 0x3c6ef372fe94f82bUL
  self.reg[3] = 0xa54ff53a5f1d36f1UL
  self.reg[4] = 0x510e527fade682d1UL
  self.reg[5] = 0x9b05688c2b3e6c1fUL
  self.reg[6] = 0x1f83d9abfb41bd6bUL
  self.reg[7] = 0x5be0cd19137e2179UL
  self.len_high = 0
  self.len_low = 0
  self.buf.fill(0)
  self.buf_index = 0
}

///|
/// Compute the Sha512 digest from given SHA512 context
pub impl CryptoHasher for SHA512 with fn finalize_into(
  self : SHA512,
  buffer : FixedArray[Byte],
  offset~ : Int,
) -> Unit {
  self._finalize_into(buffer, offset~)
}

///|
/// Compute the Sha512 digest in `FixedArray[Byte]` of some `data`. Note that Sha512 is big-endian.
pub fn[Data : ByteSource] sha512(data : Data) -> FixedArray[Byte] {
  SHA512::new()..update(data).finalize()
}

///|
pub fn sha512_from_iter(data : Iter[Byte]) -> FixedArray[Byte] {
  SHA512::new()..update_from_iter(data).finalize()
}

///|
test {
  inspect(
    bytes_to_hex_string(
      sha512(
        b"\x61\x62\x63", // abc in utf-8
      ),
    ),
    content="ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  )
  inspect(
    bytes_to_hex_string(sha512(b"")),
    content="cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
  )
  let hash1 = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  let ctx = SHA512::new()
  ctx.update(b"\x61".to_fixedarray())
  ctx.update(b"\x62".to_fixedarray())
  ctx.update(b"\x63".to_fixedarray())
  assert_eq(hash1, bytes_to_hex_string(ctx.finalize()))
  let ctx = SHA512::new()
  let data = b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64"
  for i = 0; i < data.length(); i = i + 1 {
    ctx.update(FixedArray::make(1, data[i]))
  }
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="f0b5438f3aff13de9b33130a87b2ea33b8610de70971377e8a1a8718e7dd7400b7bfa98e1d1a65b9232e3efd76483dd88b0516b72d61c1054c08efa0861101c7",
  )
  let ctx = SHA512::new()
  for i = 0; i < data.length(); i = i + 4 {
    ctx.update_from_iter(b"\x61\x62\x63\x64".iter())
  }
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="f0b5438f3aff13de9b33130a87b2ea33b8610de70971377e8a1a8718e7dd7400b7bfa98e1d1a65b9232e3efd76483dd88b0516b72d61c1054c08efa0861101c7",
  )
}

///|
test "sha512 reentry" {
  let string = b"abcd"
  let ctx = SHA512::new()
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="d8022f2060ad6efd297ab73dcc5355c9b214054b0d1776a136a669d26a7d3b14f73aa0d0ebff19ee333368f0164b6419a96da49e3e481753e7e96b716bdccb6f",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="7edbb31279e6b88ac79812e2f77f5b234f817797c7cf98263d557ecfc992f1c43e8b169e11e3aaceb4407da8390517cac5e64f579344e15f589be5c20e7cecc8",
  )
  ctx.update(string)
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="6a4138ab1f504088a275272ca996c23690ffa201cf1a516cff1e6eb2e70e6a0b4abdf25ab9e9b99778fea957f2ac02ae1874cb287f5250fd4fac10fe9280b220",
  )
}

///|
test "sha512 carries the message length into the high word" {
  let ctx = SHA512::new()
  ctx.len_low = 0xfffffffffffffc00UL
  ctx.update(FixedArray::make(128, b'\x00'))
  inspect(ctx.len_high, content="1")
  inspect(ctx.len_low, content="0")
  let ctx = SHA512::new()
  ctx.len_high = 1
  inspect(
    bytes_to_hex_string(ctx.finalize()),
    content="4e15588b073f68f07592e9a51190a7e00e2efaaa365fb318f27e82e5c6df94a862d54b825cefcc3bd28977fcefc7fd8cac281f334977797ea395dbff21311a72",
  )
}

///|
pub extend SHA512 with CryptoHasher::{reset, finalize_into, size, block_size}

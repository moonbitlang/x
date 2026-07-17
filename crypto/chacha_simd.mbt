// Copyright 2026 International Digital Economy Academy
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
#cfg(any(target="native", target="wasm"))
#inline
fn chacha4_enabled() -> Bool {
  true
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn chacha4_enabled() -> Bool {
  false
}

///|
#cfg(target="native")
#inline
fn chacha_quarter_round_v128(
  a : V128,
  b : V128,
  c : V128,
  d : V128,
) -> (V128, V128, V128, V128) {
  let a1 = @v128.i32x4_add(a, b)
  let d_xor_a = @v128.v128_xor(d, a1)
  let d1 = @v128.i8x16_shuffle(
    d_xor_a, d_xor_a, 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13,
  )
  let c1 = @v128.i32x4_add(c, d1)
  let b_xor_c = @v128.v128_xor(b, c1)
  let b1 = @v128.v128_or_(
    @v128.i32x4_shl(b_xor_c, 12),
    @v128.i32x4_shr_u(b_xor_c, 20),
  )
  let a2 = @v128.i32x4_add(a1, b1)
  let d_xor_a = @v128.v128_xor(d1, a2)
  let d2 = @v128.i8x16_shuffle(
    d_xor_a, d_xor_a, 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14,
  )
  let c2 = @v128.i32x4_add(c1, d2)
  let b_xor_c = @v128.v128_xor(b1, c2)
  let b2 = @v128.v128_or_(
    @v128.i32x4_shl(b_xor_c, 7),
    @v128.i32x4_shr_u(b_xor_c, 25),
  )
  (a2, b2, c2, d2)
}

///|
#cfg(target="native")
#inline
fn store_chacha4_word_group(
  output : FixedArray[Byte],
  byte_offset : Int,
  a : V128,
  b : V128,
  c : V128,
  d : V128,
) -> Unit {
  let ab_lo = @v128.i8x16_shuffle(
    a, b, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
  )
  let ab_hi = @v128.i8x16_shuffle(
    a, b, 8, 9, 10, 11, 24, 25, 26, 27, 12, 13, 14, 15, 28, 29, 30, 31,
  )
  let cd_lo = @v128.i8x16_shuffle(
    c, d, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
  )
  let cd_hi = @v128.i8x16_shuffle(
    c, d, 8, 9, 10, 11, 24, 25, 26, 27, 12, 13, 14, 15, 28, 29, 30, 31,
  )
  @v128.v128_store(
    output,
    byte_offset,
    @v128.i8x16_shuffle(
      ab_lo, cd_lo, 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23,
    ),
  )
  @v128.v128_store(
    output,
    byte_offset + 64,
    @v128.i8x16_shuffle(
      ab_lo, cd_lo, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31,
    ),
  )
  @v128.v128_store(
    output,
    byte_offset + 128,
    @v128.i8x16_shuffle(
      ab_hi, cd_hi, 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23,
    ),
  )
  @v128.v128_store(
    output,
    byte_offset + 192,
    @v128.i8x16_shuffle(
      ab_hi, cd_hi, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31,
    ),
  )
}

///|
#cfg(target="native")
fn chacha4BlockBytes(
  key : FixedArray[UInt],
  count : UInt,
  nonce : FixedArray[UInt],
  round : UInt,
  _scratch_words : FixedArray[UInt],
  _scratch_bytes : FixedArray[Byte],
  output : FixedArray[Byte],
) -> Unit {
  guard key.length() == 8
  guard nonce.length() == 3
  guard output.length() >= 256
  let initial0 = @v128.i32x4_splat(0X61707865)
  let initial1 = @v128.i32x4_splat(0X3320646e)
  let initial2 = @v128.i32x4_splat(0X79622d32)
  let initial3 = @v128.i32x4_splat(0X6b206574)
  let initial4 = @v128.i32x4_splat(key[0])
  let initial5 = @v128.i32x4_splat(key[1])
  let initial6 = @v128.i32x4_splat(key[2])
  let initial7 = @v128.i32x4_splat(key[3])
  let initial8 = @v128.i32x4_splat(key[4])
  let initial9 = @v128.i32x4_splat(key[5])
  let initial10 = @v128.i32x4_splat(key[6])
  let initial11 = @v128.i32x4_splat(key[7])
  let initial12 = @v128.i32x4_const(count, count + 1, count + 2, count + 3)
  let initial13 = @v128.i32x4_splat(nonce[0])
  let initial14 = @v128.i32x4_splat(nonce[1])
  let initial15 = @v128.i32x4_splat(nonce[2])
  let mut x0 = initial0
  let mut x1 = initial1
  let mut x2 = initial2
  let mut x3 = initial3
  let mut x4 = initial4
  let mut x5 = initial5
  let mut x6 = initial6
  let mut x7 = initial7
  let mut x8 = initial8
  let mut x9 = initial9
  let mut x10 = initial10
  let mut x11 = initial11
  let mut x12 = initial12
  let mut x13 = initial13
  let mut x14 = initial14
  let mut x15 = initial15
  for _ in 0U..<round {
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x0, x4, x8, x12)
      x0 = a
      x4 = b
      x8 = c
      x12 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x1, x5, x9, x13)
      x1 = a
      x5 = b
      x9 = c
      x13 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x2, x6, x10, x14)
      x2 = a
      x6 = b
      x10 = c
      x14 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x3, x7, x11, x15)
      x3 = a
      x7 = b
      x11 = c
      x15 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x0, x5, x10, x15)
      x0 = a
      x5 = b
      x10 = c
      x15 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x1, x6, x11, x12)
      x1 = a
      x6 = b
      x11 = c
      x12 = d
    }
    {
      let (a, b, c, d) = chacha_quarter_round_v128(x2, x7, x8, x13)
      x2 = a
      x7 = b
      x8 = c
      x13 = d
    }
    let (a, b, c, d) = chacha_quarter_round_v128(x3, x4, x9, x14)
    x3 = a
    x4 = b
    x9 = c
    x14 = d
  }
  x0 = @v128.i32x4_add(x0, initial0)
  x1 = @v128.i32x4_add(x1, initial1)
  x2 = @v128.i32x4_add(x2, initial2)
  x3 = @v128.i32x4_add(x3, initial3)
  x4 = @v128.i32x4_add(x4, initial4)
  x5 = @v128.i32x4_add(x5, initial5)
  x6 = @v128.i32x4_add(x6, initial6)
  x7 = @v128.i32x4_add(x7, initial7)
  x8 = @v128.i32x4_add(x8, initial8)
  x9 = @v128.i32x4_add(x9, initial9)
  x10 = @v128.i32x4_add(x10, initial10)
  x11 = @v128.i32x4_add(x11, initial11)
  x12 = @v128.i32x4_add(x12, initial12)
  x13 = @v128.i32x4_add(x13, initial13)
  x14 = @v128.i32x4_add(x14, initial14)
  x15 = @v128.i32x4_add(x15, initial15)
  store_chacha4_word_group(output, 0, x0, x1, x2, x3)
  store_chacha4_word_group(output, 16, x4, x5, x6, x7)
  store_chacha4_word_group(output, 32, x8, x9, x10, x11)
  store_chacha4_word_group(output, 48, x12, x13, x14, x15)
}

///|
#cfg(not(target="native"))
fn chacha4BlockBytes(
  key : FixedArray[UInt],
  count : UInt,
  nonce : FixedArray[UInt],
  round : UInt,
  scratch_words : FixedArray[UInt],
  scratch_bytes : FixedArray[Byte],
  output : FixedArray[Byte],
) -> Unit {
  for block in 0..<4 {
    chachaBlockBytes(
      key,
      count + block.reinterpret_as_uint(),
      nonce,
      round,
      scratch_words,
      scratch_bytes,
    )
    scratch_bytes.blit_to(output, len=64, dst_offset=block * 64)
  }
}

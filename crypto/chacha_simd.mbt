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
/// Generates one serialized ChaCha block with scalar rounds.
#cfg(not(any(target="native", target="wasm")))
fn chachaBlock(
  key : FixedArray[UInt],
  count : UInt,
  nonce : FixedArray[UInt],
  round : UInt,
  output : FixedArray[Byte],
) -> Unit {
  guard key.length() == 8
  guard nonce.length() == 3
  guard output.length() == 64
  let state = FixedArray::make(16, 0U)
  state[0] = 0X61707865U
  state[1] = 0X3320646eU
  state[2] = 0X79622d32U
  state[3] = 0X6b206574U
  key.blit_to(state, len=8, dst_offset=4)
  state[12] = count
  nonce.blit_to(state, len=3, dst_offset=13)
  state.chachaBlockLoop(round)
  state[0] += 0X61707865U
  state[1] += 0X3320646eU
  state[2] += 0X79622d32U
  state[3] += 0X6b206574U
  for i in 0..<8 {
    state[i + 4] += key[i]
  }
  state[12] += count
  for i in 0..<3 {
    state[i + 13] += nonce[i]
  }
  for i in 0..<16 {
    let word = state[i]
    output[i * 4] = word.to_byte()
    output[i * 4 + 1] = (word >> 8).to_byte()
    output[i * 4 + 2] = (word >> 16).to_byte()
    output[i * 4 + 3] = (word >> 24).to_byte()
  }
}

///|
/// Generates one ChaCha block with one state row per vector. Each lane holds
/// one consecutive word, so a row rotation aligns the lanes for the diagonal
/// rounds and its inverse restores the serialized state order.
#cfg(any(target="native", target="wasm"))
fn chachaBlock(
  key : FixedArray[UInt],
  count : UInt,
  nonce : FixedArray[UInt],
  round : UInt,
  output : FixedArray[Byte],
) -> Unit {
  guard key.length() == 8
  guard nonce.length() == 3
  let initial_a = @v128.i32x4_const(
    0X61707865, 0X3320646e, 0X79622d32, 0X6b206574,
  )
  let initial_b = @v128.i32x4_const(key[0], key[1], key[2], key[3])
  let initial_c = @v128.i32x4_const(key[4], key[5], key[6], key[7])
  let initial_d = @v128.i32x4_const(count, nonce[0], nonce[1], nonce[2])
  let mut a = initial_a
  let mut b = initial_b
  let mut c = initial_c
  let mut d = initial_d
  for _ in 0U..<round {
    // Four column quarter-rounds in parallel.
    a = @v128.i32x4_add(a, b)
    let d_xor_a = @v128.v128_xor(d, a)
    d = @v128.i8x16_shuffle(
      d_xor_a, d_xor_a, 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13,
    )
    c = @v128.i32x4_add(c, d)
    let b_xor_c = @v128.v128_xor(b, c)
    b = @v128.v128_or_(
      @v128.i32x4_shl(b_xor_c, 12),
      @v128.i32x4_shr_u(b_xor_c, 20),
    )
    a = @v128.i32x4_add(a, b)
    let d_xor_a = @v128.v128_xor(d, a)
    d = @v128.i8x16_shuffle(
      d_xor_a, d_xor_a, 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14,
    )
    c = @v128.i32x4_add(c, d)
    let b_xor_c = @v128.v128_xor(b, c)
    b = @v128.v128_or_(
      @v128.i32x4_shl(b_xor_c, 7),
      @v128.i32x4_shr_u(b_xor_c, 25),
    )

    // Rotate rows to align the same lanes for four diagonal quarter-rounds.
    b = @v128.i8x16_shuffle(
      b, b, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3,
    )
    c = @v128.i8x16_shuffle(
      c, c, 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7,
    )
    d = @v128.i8x16_shuffle(
      d, d, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    )
    a = @v128.i32x4_add(a, b)
    let d_xor_a = @v128.v128_xor(d, a)
    d = @v128.i8x16_shuffle(
      d_xor_a, d_xor_a, 2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13,
    )
    c = @v128.i32x4_add(c, d)
    let b_xor_c = @v128.v128_xor(b, c)
    b = @v128.v128_or_(
      @v128.i32x4_shl(b_xor_c, 12),
      @v128.i32x4_shr_u(b_xor_c, 20),
    )
    a = @v128.i32x4_add(a, b)
    let d_xor_a = @v128.v128_xor(d, a)
    d = @v128.i8x16_shuffle(
      d_xor_a, d_xor_a, 3, 0, 1, 2, 7, 4, 5, 6, 11, 8, 9, 10, 15, 12, 13, 14,
    )
    c = @v128.i32x4_add(c, d)
    let b_xor_c = @v128.v128_xor(b, c)
    b = @v128.v128_or_(
      @v128.i32x4_shl(b_xor_c, 7),
      @v128.i32x4_shr_u(b_xor_c, 25),
    )
    // Restore the row layout before the next column round.
    b = @v128.i8x16_shuffle(
      b, b, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
    )
    c = @v128.i8x16_shuffle(
      c, c, 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7,
    )
    d = @v128.i8x16_shuffle(
      d, d, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0, 1, 2, 3,
    )
  }
  a = @v128.i32x4_add(a, initial_a)
  b = @v128.i32x4_add(b, initial_b)
  c = @v128.i32x4_add(c, initial_c)
  d = @v128.i32x4_add(d, initial_d)
  @v128.v128_store(output, 0, a)
  @v128.v128_store(output, 16, b)
  @v128.v128_store(output, 32, c)
  @v128.v128_store(output, 48, d)
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn[Data : ByteSource] chacha_xor_into(
  data : Data,
  input_offset : Int,
  target : FixedArray[Byte],
  target_offset : Int,
  key_stream : FixedArray[Byte],
  key_stream_offset : Int,
  length : Int,
) -> Unit {
  for i in 0..<length {
    target.unsafe_set(
      target_offset + i,
      data[input_offset + i] ^ key_stream.unsafe_get(key_stream_offset + i),
    )
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn[Data : ByteSource] chacha_xor_into(
  data : Data,
  input_offset : Int,
  target : FixedArray[Byte],
  target_offset : Int,
  key_stream : FixedArray[Byte],
  key_stream_offset : Int,
  length : Int,
) -> Unit {
  data.blit_to(
    target,
    len=length,
    src_offset=input_offset,
    dst_offset=target_offset,
  )
  let simd_end = length / 16 * 16
  for relative_offset = 0
      relative_offset < simd_end
      relative_offset = relative_offset + 16 {
    @v128.v128_store(
      target,
      target_offset + relative_offset,
      @v128.v128_xor(
        @v128.v128_load(target, target_offset + relative_offset),
        @v128.v128_load(key_stream, key_stream_offset + relative_offset),
      ),
    )
  }
  for relative_offset in simd_end..<length {
    target.unsafe_set(
      target_offset + relative_offset,
      target.unsafe_get(target_offset + relative_offset) ^
      key_stream.unsafe_get(key_stream_offset + relative_offset),
    )
  }
}

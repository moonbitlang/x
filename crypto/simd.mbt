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
#cfg(any(target="native", target="wasm"))
#inline
fn parse_be_u32x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt],
) -> Unit {
  for group in 0..<4 {
    let value = @v128.v128_load(bytes, byte_offset + group * 16)
    let value = @v128.i8x16_shuffle(
      value, value, 3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12,
    )
    let word_offset = group * 4
    words.unsafe_set(word_offset, @v128.i32x4_extract_lane(value, 0))
    words.unsafe_set(word_offset + 1, @v128.i32x4_extract_lane(value, 1))
    words.unsafe_set(word_offset + 2, @v128.i32x4_extract_lane(value, 2))
    words.unsafe_set(word_offset + 3, @v128.i32x4_extract_lane(value, 3))
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn parse_be_u32x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt],
) -> Unit {
  for word_offset in 0..<16 {
    let offset = byte_offset + word_offset * 4
    words.unsafe_set(
      word_offset,
      (bytes.unsafe_get(offset).to_uint() << 24) |
      (bytes.unsafe_get(offset + 1).to_uint() << 16) |
      (bytes.unsafe_get(offset + 2).to_uint() << 8) |
      bytes.unsafe_get(offset + 3).to_uint(),
    )
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn parse_le_u32x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt],
) -> Unit {
  for group in 0..<4 {
    let value = @v128.v128_load(bytes, byte_offset + group * 16)
    let word_offset = group * 4
    words.unsafe_set(word_offset, @v128.i32x4_extract_lane(value, 0))
    words.unsafe_set(word_offset + 1, @v128.i32x4_extract_lane(value, 1))
    words.unsafe_set(word_offset + 2, @v128.i32x4_extract_lane(value, 2))
    words.unsafe_set(word_offset + 3, @v128.i32x4_extract_lane(value, 3))
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn parse_le_u32x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt],
) -> Unit {
  for word_offset in 0..<16 {
    let offset = byte_offset + word_offset * 4
    words.unsafe_set(
      word_offset,
      bytes.unsafe_get(offset).to_uint() |
      (bytes.unsafe_get(offset + 1).to_uint() << 8) |
      (bytes.unsafe_get(offset + 2).to_uint() << 16) |
      (bytes.unsafe_get(offset + 3).to_uint() << 24),
    )
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn parse_be_u64x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt64],
) -> Unit {
  for group in 0..<8 {
    let value = @v128.v128_load(bytes, byte_offset + group * 16)
    let value = @v128.i8x16_shuffle(
      value, value, 7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8,
    )
    let word_offset = group * 2
    words.unsafe_set(word_offset, @v128.i64x2_extract_lane(value, 0))
    words.unsafe_set(word_offset + 1, @v128.i64x2_extract_lane(value, 1))
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn parse_be_u64x16_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[UInt64],
) -> Unit {
  for word_offset in 0..<16 {
    let offset = byte_offset + word_offset * 8
    words.unsafe_set(
      word_offset,
      (bytes.unsafe_get(offset).to_uint64() << 56) |
      (bytes.unsafe_get(offset + 1).to_uint64() << 48) |
      (bytes.unsafe_get(offset + 2).to_uint64() << 40) |
      (bytes.unsafe_get(offset + 3).to_uint64() << 32) |
      (bytes.unsafe_get(offset + 4).to_uint64() << 24) |
      (bytes.unsafe_get(offset + 5).to_uint64() << 16) |
      (bytes.unsafe_get(offset + 6).to_uint64() << 8) |
      bytes.unsafe_get(offset + 7).to_uint64(),
    )
  }
}

///|
#cfg(any(target="native", target="wasm"))
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  let simd_end = length / 16 * 16
  let vector_mask = @v128.i8x16_splat(mask)
  for offset = 0; offset < simd_end; offset = offset + 16 {
    @v128.v128_load(bytes, offset)
    |> @v128.v128_xor(vector_mask)
    |> value => { @v128.v128_store(bytes, offset, value) }
  }
  for offset in simd_end..<length {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  for offset in 0..<length {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

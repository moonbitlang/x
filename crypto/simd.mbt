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
fn load_u32x16_be_into(
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
fn load_u32x16_be_into(
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
fn load_i32x16_be_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[Int],
) -> Unit {
  for group in 0..<4 {
    let value = @v128.v128_load(bytes, byte_offset + group * 16)
    let value = @v128.i8x16_shuffle(
      value, value, 3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12,
    )
    let word_offset = group * 4
    words.unsafe_set(
      word_offset,
      @v128.i32x4_extract_lane(value, 0).reinterpret_as_int(),
    )
    words.unsafe_set(
      word_offset + 1,
      @v128.i32x4_extract_lane(value, 1).reinterpret_as_int(),
    )
    words.unsafe_set(
      word_offset + 2,
      @v128.i32x4_extract_lane(value, 2).reinterpret_as_int(),
    )
    words.unsafe_set(
      word_offset + 3,
      @v128.i32x4_extract_lane(value, 3).reinterpret_as_int(),
    )
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn load_i32x16_be_into(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  words : FixedArray[Int],
) -> Unit {
  for word_offset in 0..<16 {
    let offset = byte_offset + word_offset * 4
    words.unsafe_set(
      word_offset,
      (bytes.unsafe_get(offset).to_int() << 24) |
      (bytes.unsafe_get(offset + 1).to_int() << 16) |
      (bytes.unsafe_get(offset + 2).to_int() << 8) |
      bytes.unsafe_get(offset + 3).to_int(),
    )
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn load_u32x16_le_into(
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
fn load_u32x16_le_into(
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
fn store_u32x4_le(
  words : FixedArray[UInt],
  word_offset : Int,
  bytes : FixedArray[Byte],
  byte_offset : Int,
) -> Unit {
  @v128.v128_store(
    bytes,
    byte_offset,
    @v128.i32x4_const(
      words.unsafe_get(word_offset),
      words.unsafe_get(word_offset + 1),
      words.unsafe_get(word_offset + 2),
      words.unsafe_get(word_offset + 3),
    ),
  )
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn store_u32x4_le(
  words : FixedArray[UInt],
  word_offset : Int,
  bytes : FixedArray[Byte],
  byte_offset : Int,
) -> Unit {
  for lane in 0..<4 {
    let word = words.unsafe_get(word_offset + lane)
    let offset = byte_offset + lane * 4
    bytes.unsafe_set(offset, word.to_byte())
    bytes.unsafe_set(offset + 1, (word >> 8).to_byte())
    bytes.unsafe_set(offset + 2, (word >> 16).to_byte())
    bytes.unsafe_set(offset + 3, (word >> 24).to_byte())
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  let simd_end = length / 16 * 16
  let vector_mask = @v128.i8x16_splat(mask)
  for offset = 0; offset < simd_end; offset = offset + 16 {
    @v128.v128_store(
      bytes,
      offset,
      @v128.v128_xor(@v128.v128_load(bytes, offset), vector_mask),
    )
  }
  for offset = simd_end; offset < length; offset = offset + 1 {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

///|
#cfg(any(target="native", target="wasm"))
#inline
fn xor_byte_ranges_in_place(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  mask : FixedArray[Byte],
  mask_offset : Int,
  length : Int,
) -> Unit {
  let simd_end = length / 16 * 16
  for offset = 0; offset < simd_end; offset = offset + 16 {
    @v128.v128_store(
      bytes,
      byte_offset + offset,
      @v128.v128_xor(
        @v128.v128_load(bytes, byte_offset + offset),
        @v128.v128_load(mask, mask_offset + offset),
      ),
    )
  }
  for offset = simd_end; offset < length; offset = offset + 1 {
    bytes.unsafe_set(
      byte_offset + offset,
      bytes.unsafe_get(byte_offset + offset) ^
      mask.unsafe_get(mask_offset + offset),
    )
  }
}

///|
#cfg(not(any(target="native", target="wasm", target="js")))
#inline
fn xor_byte_ranges_in_place(
  bytes : FixedArray[Byte],
  byte_offset : Int,
  mask : FixedArray[Byte],
  mask_offset : Int,
  length : Int,
) -> Unit {
  for offset in 0..<length {
    bytes.unsafe_set(
      byte_offset + offset,
      bytes.unsafe_get(byte_offset + offset) ^
      mask.unsafe_get(mask_offset + offset),
    )
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
#inline
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  for offset in 0..<length {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

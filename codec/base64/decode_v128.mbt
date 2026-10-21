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

// Adapted from moonbitlang/core (Apache-2.0):
// https://github.com/moonbitlang/core/blob/4738353132cfe6a84651377b5523b66f5f6c6742/encoding/base64/decode_v128.mbt
// Copyright 2026 International Digital Economy Academy
// Extended for x's URL-safe alphabet and existing decoder semantics.

// Vectorized Base64 decoding for the linear-memory backends. The character
// classification uses the perfect hash on the high nibble described in
// https://mcyoung.xyz/2023/11/27/simd-base64/.
//
// A MoonBit `String` is UTF-16, so a block loads two vectors of eight code
// units to obtain sixteen characters, which yield twelve decoded bytes.
//
// The fast path handles alphabet-only blocks and leaves the final group to
// x's scalar decoder. It deliberately preserves x's permissive padding and
// trailing-bit behavior instead of importing core's stricter validation.

///|
/// True when every lane holds a character of the selected Base64 alphabet.
/// Padding and whitespace deliberately fail this test so the caller continues
/// with the scalar decoder from this block.
#cfg(any(target="native", target="wasm"))
fn decode_valid_v128(ascii : V128, url_safe : Bool) -> Bool {
  let upper = @v128.v128_and_(
    @v128.i8x16_ge_u(ascii, @v128.i8x16_splat(b'A')),
    @v128.i8x16_le_u(ascii, @v128.i8x16_splat(b'Z')),
  )
  let lower = @v128.v128_and_(
    @v128.i8x16_ge_u(ascii, @v128.i8x16_splat(b'a')),
    @v128.i8x16_le_u(ascii, @v128.i8x16_splat(b'z')),
  )
  let digit = @v128.v128_and_(
    @v128.i8x16_ge_u(ascii, @v128.i8x16_splat(b'0')),
    @v128.i8x16_le_u(ascii, @v128.i8x16_splat(b'9')),
  )
  let plus = @v128.i8x16_eq(
    ascii,
    @v128.i8x16_splat(if url_safe { b'-' } else { b'+' }),
  )
  let slash = @v128.i8x16_eq(
    ascii,
    @v128.i8x16_splat(if url_safe { b'_' } else { b'/' }),
  )
  @v128.i8x16_all_true(
    @v128.v128_or_(
      @v128.v128_or_(upper, lower),
      @v128.v128_or_(digit, @v128.v128_or_(plus, slash)),
    ),
  )
}

///|
/// Turns sixteen Base64 characters into twelve decoded bytes, held in the low
/// twelve lanes of the result.
#cfg(any(target="native", target="wasm"))
fn decode_block_v128(ascii : V128, url_safe : Bool) -> V128 {
  // The alphabet was already checked. Normalize '-' to '+' (subtract 2)
  // and '_' to '/' (subtract 48) without copying or accepting the wrong alphabet.
  let ascii = if url_safe {
    @v128.i8x16_sub(
      ascii,
      @v128.v128_or_(
        @v128.v128_and_(
          @v128.i8x16_eq(ascii, @v128.i8x16_splat(b'-')),
          @v128.i8x16_splat(2),
        ),
        @v128.v128_and_(
          @v128.i8x16_eq(ascii, @v128.i8x16_splat(b'_')),
          @v128.i8x16_splat(48),
        ),
      ),
    )
  } else {
    ascii
  }
  // `i8x16_eq` yields all-ones, i.e. -1, so adding it subtracts one for '/'.
  let hash = @v128.i8x16_add(
    @v128.i8x16_shr_u(ascii, 4),
    @v128.i8x16_eq(ascii, @v128.i8x16_splat(b'/')),
  )
  // Hash classes: 1 -> '/', 2 -> '+', 3 -> digits, 4..5 -> uppercase,
  // 6..7 -> lowercase. Offsets wrap modulo 256.
  let offsets = @v128.i8x16_const(
    0, 16, 19, 4, 191, 191, 185, 185, 0, 0, 0, 0, 0, 0, 0, 0,
  )
  let sextets = @v128.i8x16_add(ascii, @v128.i8x16_swizzle(offsets, hash))
  // Fuse each group of four sextets into a 24-bit value held in the low three
  // bytes of its 32-bit lane.
  let groups = @v128.v128_or_(
    @v128.v128_or_(
      @v128.i32x4_shl(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x0000003F)),
        18,
      ),
      @v128.i32x4_shl(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x00003F00)),
        4,
      ),
    ),
    @v128.v128_or_(
      @v128.i32x4_shr_u(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x003F0000)),
        10,
      ),
      @v128.i32x4_shr_u(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x3F000000)),
        24,
      ),
    ),
  )
  // Emit each lane's three payload bytes most-significant first.
  @v128.i8x16_shuffle(
    groups, groups, 2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, 0, 0, 0, 0,
  )
}

///|
// Decode complete vector blocks, then continue scalar decoding from the first
// unconsumed block. Keep completed output when padding or an error is encountered.
#cfg(any(target="native", target="wasm"))
fn decode_v128(text : StringView, url_safe : Bool) -> Bytes raise DecodeError {
  let length = text.length()
  // Small inputs stay scalar. Reserve the final group for padding handling.
  guard length >= 32 && length % 4 == 0 else {
    return decode_scalar(text, url_safe~)
  }
  let padding = if text[length - 1] != '=' {
    0
  } else if text[length - 2] != '=' {
    1
  } else {
    2
  }
  let out = FixedArray::make(length / 4 * 3 - padding, b'\x00')
  let src = text.data()
  // The final group may carry padding, so it is always left to the scalar
  // decoder; everything before it must be plain alphabet.
  let body = length - 4
  let base = text.start_offset()
  let mut index = 0
  let mut written = 0
  // Each vector store writes 16 bytes although only 12 are payload. Leave
  // room for the store; subsequent blocks and the scalar tail overwrite it.
  while body - index >= 16 && out.length() - written >= 16 {
    let offset = base + index
    let ascii = @v128.i8x16_narrow_i16x8_u(
      @v128.v128_load_i16x8(src, offset),
      @v128.v128_load_i16x8(src, offset + 8),
    )
    guard decode_valid_v128(ascii, url_safe) else { break }
    @v128.v128_store(out, written, decode_block_v128(ascii, url_safe))
    index += 16
    written += 12
  }
  // Each vector consumed four whole Base64 groups, so the scalar decoder can
  // start with empty state. It handles the remaining groups, permissive padding,
  // and Unicode errors without rescanning or discarding the completed prefix.
  let decoder = Decoder::new()
  decoder.decode_to(
    text[index:],
    byte => {
      out[written] = byte
      written += 1
    },
    url_safe~,
  )
  if written == out.length() {
    out.unsafe_reinterpret_as_bytes()
  } else {
    // Early padding can leave unused capacity, including overlapping SIMD
    // stores beyond the last payload byte. Return only the decoded prefix.
    Bytes::from_array(out[:written])
  }
}

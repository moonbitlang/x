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
pub fn[Data : ByteSource] sha1(input : Data) -> FixedArray[Byte] {
  // Padding
  let old_length = input.length()
  let bits = old_length.to_uint64() * 8
  let mut new_length = (old_length / 64 + 1) * 64
  if new_length - old_length < 9 {
    new_length += 64
  }
  let bytes = FixedArray::make(new_length, b'\x00')
  input.blit_to(bytes, len=old_length, src_offset=0, dst_offset=0)
  bytes[old_length] = (0x80).to_byte()
  for i = new_length - 8; i < new_length; i = i + 1 {
    bytes[i] = (bits >> (56 - (i - (new_length - 8)) * 8)).to_byte()
  }
  // Hash
  let h = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
  let bytes_per_chunk = 512 / 8
  let chunk_count = new_length / bytes_per_chunk // `new_length` is a multiple of 512
  let words = FixedArray::make(80, 0)
  for chunk = 0; chunk < chunk_count; chunk = chunk + 1 {
    load_i32x16_be_into(bytes, chunk * bytes_per_chunk, words)
    for i = 16; i < 80; i = i + 1 {
      words[i] = rotate_left(
        words[i - 3] ^ words[i - 8] ^ words[i - 14] ^ words[i - 16],
        1,
      )
    }
    let mut a = h[0]
    let mut b = h[1]
    let mut c = h[2]
    let mut d = h[3]
    let mut e = h[4]
    for i in 0..<20 {
      let f = (b & c) | (b.lnot() & d)
      let temp = rotate_left(a, 5) + f + e + 0x5A827999 + words[i]
      e = d
      d = c
      c = rotate_left(b, 30)
      b = a
      a = temp
    }
    for i in 20..<40 {
      let f = b ^ c ^ d
      let temp = rotate_left(a, 5) + f + e + 0x6ED9EBA1 + words[i]
      e = d
      d = c
      c = rotate_left(b, 30)
      b = a
      a = temp
    }
    for i in 40..<60 {
      let f = (b & c) | (b & d) | (c & d)
      let temp = rotate_left(a, 5) + f + e + 0x8F1BBCDC + words[i]
      e = d
      d = c
      c = rotate_left(b, 30)
      b = a
      a = temp
    }
    for i in 60..<80 {
      let f = b ^ c ^ d
      let temp = rotate_left(a, 5) + f + e + 0xCA62C1D6 + words[i]
      e = d
      d = c
      c = rotate_left(b, 30)
      b = a
      a = temp
    }
    h[0] += a
    h[1] += b
    h[2] += c
    h[3] += d
    h[4] += e
  }
  // Digest
  let result = FixedArray::make(20, b'\x00')
  for i = 0; i < 5; i = i + 1 {
    result[i * 4 + 0] = (h[i].reinterpret_as_uint() >> 24).to_byte()
    result[i * 4 + 1] = (h[i].reinterpret_as_uint() >> 16).to_byte()
    result[i * 4 + 2] = (h[i].reinterpret_as_uint() >> 8).to_byte()
    result[i * 4 + 3] = h[i].to_byte()
  }
  result
}

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

/// Converts a byte array to a hex string, without any prefix like "0x".

let hex_digits : FixedArray[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
]

/// print a sequence of byte in hex representation
pub fn bytes_to_hex_string(input : Bytes) -> String {
  let mut ret = ""
  for i = input.length() - 1; i >= 0; i = i - 1 {
    let byte = input[i]
    let high = byte.to_int().lsr(4).land(0xf)
    let low = byte.to_int().land(0xf)
    let high_char = hex_digits[high]
    let low_char = hex_digits[low]
    ret = high_char + low_char + ret
  }
  ret
}

fn uint_to_hex_string(input : UInt) -> String {
  let ret = FixedArray::make(8, "0")
  let mut mut_input = input
  let mut i = 7
  for cnt = 0; cnt < 8; cnt = cnt + 1 {
    ret[i] = hex_digits[(mut_input & 0xf).to_int()]
    mut_input = mut_input.lsr(4)
    i -= 1
  }
  ret.fold_left(String::op_add, init="")
}

/// print a sequence of uint in hex representation
pub fn uints_to_hex_string(input : Array[UInt]) -> String {
  input.map(uint_to_hex_string).fold_left(String::op_add, init="")
}

fn urotate_left(x : UInt, n : Int) -> UInt {
  rotate_left_u(x, n)
}

fn uint32(x : Byte) -> UInt {
  x.to_int().to_uint()
}

/// convert 4 bytes a byte sequence to a UInt in little endian
/// - `x` : A byte sequence consisting of 4 or more bytes
/// - `i` : An offset. e.g. i = 4 will convert `x[4~7]` to a UInt.
pub fn u8_to_u32le(x : Bytes, ~i : Int = 0) -> UInt {
  uint32(x[i]) | uint32(x[i + 1]).lsl(8) | uint32(x[i + 2]).lsl(16) | uint32(
    x[i + 3],
  ).lsl(24)
}

/// convert 4 bytes of a byte sequence to a UInt in big endian 
/// - `x` : A byte sequence consisting of 4 or more bytes
/// - `i` : An offset. e.g. i = 4 will convert `x[4~7]` to a UInt.
pub fn u8_to_u32be(x : Bytes, ~i : Int = 0) -> UInt {
  uint32(x[i]).lsl(24) | uint32(x[i + 1]).lsl(16) | uint32(x[i + 2]).lsl(8) | uint32(
    x[i + 3],
  )
}

/// convert 4 bytes of a byte array to a UInt in big endian 
/// - `x` : A byte sequence consisting of 4 or more bytes
/// - `i` : An offset. e.g. i = 4 will convert `x[4~7]` to a UInt.
pub fn arr_u8_to_u32be(x : Array[Byte], ~i : Int = 0) -> UInt {
  uint32(x[i]).lsl(24) | uint32(x[i + 1]).lsl(16) | uint32(x[i + 2]).lsl(8) | uint32(
    x[i + 3],
  )
}

/// convert a UInt to 4 bytes
pub fn u32_to_u8be(x : UInt) -> Array[Byte] {
  let b = Array::make(4, b'\x00')
  b[0] = x.lsr(24).to_byte()
  b[1] = x.lsr(16).to_byte()
  b[2] = x.lsr(8).to_byte()
  b[3] = x.to_byte()
  b
}

/// convert an array of UInt to Bytes in big endian
pub fn arr_u32_to_u8be(x : Array[UInt]) -> Bytes {
  let temp : Bytes = Bytes::make(x.length() * 4, b'\x00')
  for index = 0; index < x.length(); index = index + 1 {
    let u8 = u32_to_u8be(x[index])
    temp[index * 4] = u8[0]
    temp[index * 4 + 1] = u8[1]
    temp[index * 4 + 2] = u8[2]
    temp[index * 4 + 3] = u8[3]
  }
  temp
}

/// rotate a Int `x` left by `n` bit(s)
pub fn rotate_left(x : Int, n : Int) -> Int {
  x.lsl(n).lor(x.lsr(32 - n))
}

/// rotate a UInt `x` left by `n` bit(s)
fn rotate_left_u(x : UInt, n : Int) -> UInt {
  x.lsl(n) | x.lsr(32 - n)
}

/// temp function for convert bytes_to_iter in absence of `Bytes::iter()`.
pub fn bytes_to_iter(data : Bytes) -> Iter[Byte] {
  Iter::new(
    fn(yield) {
      for i = 0, len = data.length(); i < len; i = i + 1 {
        if yield(data[i]) == IterEnd {
          break IterEnd
        }
      } else {
        IterContinue
      }
    },
  )
}

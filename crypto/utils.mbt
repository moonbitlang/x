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

pub fn uints_to_hex_string(input : Array[UInt]) -> String {
  input.map(uint_to_hex_string).fold_left(String::op_add, init="")
}

fn urotate_left(x : UInt, n : Int) -> UInt {
  rotate_left_u(x, n)
}

fn uint32(x : Byte) -> UInt {
  x.to_int().to_uint()
}

pub fn u8_to_u32le(x : Bytes, ~i : Int = 0) -> UInt {
  uint32(x[i]) | uint32(x[i + 1]).lsl(8) | uint32(x[i + 2]).lsl(16) | uint32(
    x[i + 3],
  ).lsl(24)
}

pub fn u8_to_u32be(x : Bytes, ~i : Int = 0) -> UInt {
  uint32(x[i]).lsl(24) | uint32(x[i + 1]).lsl(16) | uint32(x[i + 2]).lsl(8) | uint32(
    x[i + 3],
  )
}

pub fn arr_u8_to_u32be(x : Array[Byte], ~i : Int = 0) -> UInt {
  uint32(x[i]).lsl(24) | uint32(x[i + 1]).lsl(16) | uint32(x[i + 2]).lsl(8) | uint32(
    x[i + 3],
  )
}

pub fn byte_array_to_bytes(s : Array[Byte]) -> Bytes {
  let bytes = Bytes::make(s.length(), b'\x00')
  for index = 0; index < s.length(); index = index + 1 {
    bytes[index] = s[index]
  }
  bytes
}

pub fn bytes_to_byte_array(s : Bytes) -> Array[Byte] {
  let byte_array = Array::make(s.length(), b'\x00')
  for index = 0; index < s.length(); index = index + 1 {
    byte_array[index] = s[index]
  }
  byte_array
}

fn rotate_left(x : Int, n : Int) -> Int {
  x.lsl(n).lor(x.lsr(32 - n))
}

fn rotate_left_u(x : UInt, n : Int) -> UInt {
  x.lsl(n) | x.lsr(32 - n)
}

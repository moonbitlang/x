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
/// Converts a byte array to a hex string, without any prefix like "0x".
let hex_digits : FixedArray[String] = [
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
]

///|
/// print a sequence of byte in hex representation
pub fn[D : ByteSource] bytes_to_hex_string(input : D) -> String {
  let length = input.length()
  let buffer = StringBuilder::new(size_hint=length * 2)
  for i in 0..<length {
    let byte = input[i]
    let high = (byte.to_uint() >> 4) & 0xf
    let low = byte.to_int() & 0xf
    buffer.write_string(hex_digits[high.reinterpret_as_int()])
    buffer.write_string(hex_digits[low])
  }
  buffer.to_string()
}

///|
const HEX_DIGITS = "0123456789abcdef"

///|
/// convert a sequence of `UInt` to hex representation
pub fn uints_to_hex_string(input : Iter[UInt]) -> String {
  let buffer = StringBuilder::new()
  let rems : FixedArray[Int] = FixedArray::make(8, 0)
  for x in input {
    let mut value = x
    for i in 0..<8 {
      let rem = value & 0x0f
      let quot = value >> 4
      value = quot
      rems[8 - i - 1] = rem.reinterpret_as_int()
    }
    for xdigit in rems {
      buffer.write_char(
        HEX_DIGITS.code_unit_at(xdigit).to_int() |> Int::unsafe_to_char,
      )
    }
  }
  buffer.to_string()
}

///|
test "uints_to_hex_string" {
  let xs : Array[UInt] = [0x12345678, 0xabcdcdab]
  inspect(uints_to_hex_string(xs.iter()), content="12345678abcdcdab")
}

///|
fn arr_u32_to_u8be_into(
  x : Iter[UInt],
  buffer : FixedArray[Byte],
  offset : Int,
) -> Unit {
  let mut idx = offset
  x.each(fn(d) {
    buffer[idx + 0] = (d >> 24).to_byte()
    buffer[idx + 1] = (d >> 16).to_byte()
    buffer[idx + 2] = (d >> 8).to_byte()
    buffer[idx + 3] = d.to_byte()
    idx += 4
  })
}

///|
fn arr_u32_to_u8le_into(
  x : Iter[UInt],
  buffer : FixedArray[Byte],
  offset : Int,
) -> Unit {
  let mut idx = offset
  x.each(fn(d) {
    buffer[idx + 0] = d.to_byte()
    buffer[idx + 1] = (d >> 8).to_byte()
    buffer[idx + 2] = (d >> 16).to_byte()
    buffer[idx + 3] = (d >> 24).to_byte()
    idx += 4
  })
}

///|
fn arr_u64_to_u8be_into(
  x : Iter[UInt64],
  buffer : FixedArray[Byte],
  offset : Int,
) -> Unit {
  let mut idx = offset
  x.each(fn(d) {
    buffer[idx + 0] = (d >> 56).to_byte()
    buffer[idx + 1] = (d >> 48).to_byte()
    buffer[idx + 2] = (d >> 40).to_byte()
    buffer[idx + 3] = (d >> 32).to_byte()
    buffer[idx + 4] = (d >> 24).to_byte()
    buffer[idx + 5] = (d >> 16).to_byte()
    buffer[idx + 6] = (d >> 8).to_byte()
    buffer[idx + 7] = d.to_byte()
    idx += 8
  })
}

///|
/// rotate a UInt64 `x` right by `n` bit(s)
fn rotate_right_u64(x : UInt64, n : Int) -> UInt64 {
  (x >> n) | (x << (64 - n))
}

///|
/// rotate a UInt `x` left by `n` bit(s)
fn rotate_left_u(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

///|
fn rotate_right_u(x : UInt, n : Int) -> UInt {
  (x >> n) | (x << (32 - n))
}

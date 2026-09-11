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
/// Percent-encodes the UTF-8 bytes of input as uppercase %HH escapes. Non-ASCII
/// bytes and the ASCII characters in escape_chars are escaped. By default, only
/// ASCII letters and digits are unescaped.
/// Include '%' in a custom escape_chars value to escape literal percent signs.
/// Duplicate and non-ASCII characters in escape_chars are ignored.
pub fn encode(
  input : StringView,
  escape_chars? : StringView = non_alphanumeric,
) -> String {
  let mut lower = 0UL
  let mut upper = 0UL
  for char in escape_chars {
    let value = char.to_int()
    if value < 64 {
      lower = lower | (1UL << value)
    } else if value < 128 {
      upper = upper | (1UL << (value - 64))
    }
  }
  let output = StringBuilder(size_hint=input.length())
  let hex = b"0123456789ABCDEF"
  for byte in @utf8.encode(input) {
    let value = byte.to_int()
    let selected = if value < 64 {
      (lower & (1UL << value)) != 0
    } else if value < 128 {
      (upper & (1UL << (value - 64))) != 0
    } else {
      true
    }
    if selected {
      output.write_char('%')
      output.write_char(hex[value >> 4].to_int().unsafe_to_char())
      output.write_char(hex[value & 15].to_int().unsafe_to_char())
    } else {
      output.write_char(value.unsafe_to_char())
    }
  }
  output.to_string()
}

///|
/// Decodes %HH escapes once, preserving malformed escapes and literal '+'.
/// Unescaped text is encoded as UTF-8. The result is arbitrary bytes; UTF-8
/// decoding is a separate operation.
pub fn decode(input : StringView) -> Bytes {
  let input = @utf8.encode(input)
  let output = @buffer.Buffer(size_hint=input.length())
  for i = 0; i < input.length(); {
    let byte = input[i]
    if byte == b'%' && input.length() - i >= 3 {
      let hi = hex_value(input[i + 1])
      let lo = hex_value(input[i + 2])
      if hi >= 0 && lo >= 0 {
        output.write_byte(((hi << 4) | lo).to_byte())
        continue i + 3
      }
    }
    output.write_byte(byte)
    continue i + 1
  }
  output.to_bytes()
}

///|
fn hex_value(byte : Byte) -> Int {
  match byte {
    b'0'..=b'9' => byte.to_int() - b'0'.to_int()
    b'A'..=b'F' => byte.to_int() - b'A'.to_int() + 10
    b'a'..=b'f' => byte.to_int() - b'a'.to_int() + 10
    _ => -1
  }
}

///|
/// ASCII control characters: U+0000 through U+001F, and U+007F.
pub let controls : String = String::from_array(
    [
      for value in 0..<32 => value.unsafe_to_char()
    ],
  ) +
  "\u007F"

///|
/// All ASCII characters except letters and digits.
pub let non_alphanumeric : String = {
  let chars = StringBuilder()
  for value in 0..<128 {
    if !(value is ('A'..='Z' | 'a'..='z' | '0'..='9')) {
      chars.write_char(value.unsafe_to_char())
    }
  }
  chars.to_string()
}

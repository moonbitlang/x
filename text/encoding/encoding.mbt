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

pub enum Encoding {
  UTF8
  UTF16_BOM
  UTF16_BE
  UTF16_LE
  UTF32_BOM
  UTF32_BE
  UTF32_LE
}

fn swap_endian(bytes : Bytes) -> Bytes {
  let swapped = Bytes::make(bytes.length())
  for i = 0; i < bytes.length(); i = i + 1 {
    swapped[i] = bytes[bytes.length() - i - 1]
  }
  swapped
}

/// encode given string to specific text encoding
pub fn Encoding::encode(
  encoding : Encoding,
  str : String
) -> Result[Bytes, String] {
  fn codepoint_of_surrogate_pair(high : Int, low : Int) -> Int {
    let h = (high - 0xD800).lsl(10)
    let l = low - 0xDC00
    h + l + 0x10000
  }

  match encoding {
    UTF16_LE => return Ok(str.to_bytes())
    UTF16_BE => return Ok(swap_endian(str.to_bytes()))
    UTF8 => {
      fn utf8_of_codepoint(codepoint : Int) -> Array[Int] {
        if codepoint <= 0x7F {
          [codepoint]
        } else if codepoint <= 0x7FF {
          [(0xC0).lor(codepoint.lsr(6)), (0x80).lor(codepoint.land(0x3F))]
        } else if codepoint <= 0xFFFF {
          [
            (0xE0).lor(codepoint.lsr(12)),
            (0x80).lor(codepoint.lsr(6).land(0x3F)),
            (0x80).lor(codepoint.land(0x3F)),
          ]
        } else if codepoint <= 0x10FFFF {
          [
            (0xF0).lor(codepoint.lsr(18)),
            (0x80).lor(codepoint.lsr(12).land(0x3F)),
            (0x80).lor(codepoint.lsr(6).land(0x3F)),
            (0x80).lor(codepoint.land(0x3F)),
          ]
        } else {
          abort("Invalid codepoint")
        }
      }

      let mut i = 0
      let acc : Array[Int] = []
      while i < str.length() {
        let high = str[i].to_int()
        if high >= 0xD800 && high <= 0xDDBFF {
          if i + 1 < str.length() {
            let low = str[i + 1].to_int()
            if low >= 0xDC00 && low <= 0xDFFF {
              // low surrogate
              let codepoint = codepoint_of_surrogate_pair(high, low)
              acc.append(utf8_of_codepoint(codepoint))
              i = i + 2
            } else {
              abort("Invalid surrogate pair")
            }
          } else {
            abort("Invalid surrogate pair")
          }
        } else {
          let codepoint = high
          acc.append(utf8_of_codepoint(codepoint))
          i = i + 1
        }
      }
      let utf8 = Bytes::from_array(acc)
      return Ok(utf8)
    }
    UTF32_LE => {
      let mut i = 0
      let acc : Array[Int] = []
      while i < str.length() {
        let high = str[i].to_int()
        if high >= 0xD800 && high <= 0xDDBFF {
          if i + 1 < str.length() {
            let low = str[i + 1].to_int()
            if low >= 0xDC00 && low <= 0xDFFF {
              // low surrogate
              let codepoint = codepoint_of_surrogate_pair(high, low)
              acc.push(codepoint)
              i = i + 2
            } else {
              abort("Invalid UTF-16 sequence: Missing low surrogate")
            }
          } else {
            abort("Invalid UTF-16 sequence.")
          }
        } else {
          let codepoint = high
          acc.push(codepoint)
          i = i + 1
        }
      }
      let utf32 = Bytes::from_array(acc)
      return Ok(utf32)
    }
    UTF32_BE => {
      let res = swap_endian(Encoding::encode(UTF32_LE, str)?)
      return Ok(res)
    }
    _ => abort("TODO: BOM is not implemented")
  }
}

/// encode string to specific text encoding and write into buffer
pub fn encode_into(self : Encoding, str : String, buf : Buffer) -> Unit {
  abort("TODO: need Buffer::write_byte")
}

/// decode specific text encoding to string
pub fn decode(self : Encoding, bytes : Bytes) -> Result[String, String] {
  abort("TODO: need unsafe_bytes_to_string primitive")
}

test "endode" {
  // Little 
  let s : String = "h"
  let res = encode(UTF16_BE, s)
  inspect(res, content="栀")?
}

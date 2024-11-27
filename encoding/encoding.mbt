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

///|
/// Encode a given string to the specified character encoding and returns the resulting bytes.
///
/// # Parameters
///
/// - `encoding` : The target encoding format.
/// - `src`: The input string to be encoded.
///
/// # Returns
///
/// A `bytes` representing the encoded string in the selected format.
///
/// # Examples
///
/// ```moonbit
/// let src = "Hello, World!"
/// let encoded_bytes = encode(UTF8, src)
/// ```
pub fn encode(encoding : Encoding, src : String) -> Bytes {
  // NOTE: special case: MoonBit String are already valid UTF16(LE) bytes
  match encoding {
    UTF16 | UTF16LE => return src.to_bytes()
    _ => ()
  }
  let bytes = src.to_bytes()
  let chars = decode_strict(UTF16LE, bytes)
  let new_buf = @buffer.T::new(size_hint=bytes.length())
  let write = match encoding {
    UTF8 => write_utf8_char
    UTF16BE => write_utf16be_char
    _ => abort("unreachable")
  }
  for char in chars {
    // SAFETY: Assume String are always valid UTF16LE
    write(new_buf, char.unwrap())
  }
  new_buf.to_bytes()
}

///|
fn write_char(
  write : (FixedArray[Byte], Int, Char) -> Int
) -> (@buffer.T, Char) -> Unit {
  let fixedArr = FixedArray::makei(4, fn { _ => b'\x00' })
  fn {
    buf, value => {
      let len = write(fixedArr, 0, value)
      let arr = fixedArr.iter().take(len).collect()
      buf.write_bytes(@bytes.from_array(arr))
    }
  }
}

///|
/// Write a char into buffer as UTF8.
pub let write_utf8_char : (@buffer.T, Char) -> Unit = write_char(
  FixedArray::set_utf8_char,
)

///|
/// Write a char into buffer as UTF16LE.
/// Alias for `write_utf16le_char`
pub let write_utf16_char : (@buffer.T, Char) -> Unit = @buffer.write_char

///|
/// Write a char into buffer as UTF16LE.
pub let write_utf16le_char : (@buffer.T, Char) -> Unit = @buffer.write_char

///|
/// Write a char into buffer as UTF16BE.
pub let write_utf16be_char : (@buffer.T, Char) -> Unit = write_char(
  FixedArray::set_utf16be_char,
)

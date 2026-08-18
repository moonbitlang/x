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
/// ```moonbit check
/// test {
///   let src = "Hello, World!"
///   let encoded_bytes = encode(UTF8, src)
///   assert_eq(
///     encoded_bytes,
///     Bytes::from_array([
///       72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33,
///     ]),
///   )
/// }
/// ```
pub fn encode(encoding : Encoding, src : String) -> Bytes {
  // NOTE: special case: MoonBit String are already valid UTF16(LE) bytes
  match encoding {
    UTF16 | UTF16LE => {
      let arr = FixedArray::make(src.length() * 2, b'\x00')
      arr.blit_from_string(0, src, 0, src.length())
      return arr.unsafe_reinterpret_as_bytes()
    }
    _ => ()
  }
  let new_buf = Buffer(size_hint=src.length() * 4)
  let write = match encoding {
    UTF8 => Buffer::write_char_utf8
    UTF16BE => Buffer::write_char_utf16be
    _ => abort("unreachable")
  }
  for char in src {
    // SAFETY: Assume String are always valid UTF16LE
    write(new_buf, char)
  }
  new_buf.to_bytes()
}

///|
/// Encodes a string into the specified character encoding and writes the result
/// directly into a buffer.
///
/// Parameters:
///
/// * `string` : The input string to be encoded.
/// * `buffer` : The buffer where the encoded bytes will be written to.
/// * `encoding` : The target encoding format. Defaults to UTF8 if not specified.
///
/// Example:
///
/// ```moonbit check
/// test {
///   let buf = Buffer()
///   let text = "Hello, world"
///   buf.write_string_utf16le(text)
///   inspect(buf.to_string(), content="Hello, world")
/// }
/// ```
#deprecated("Use `buffer.write_string_utf8/utf16le/utf16be` instead")
pub fn encode_to(
  src : String,
  buffer : @buffer.Buffer,
  encoding~ : Encoding,
) -> Unit {
  match encoding {
    UTF8 => buffer.write_string_utf8(src)
    UTF16BE => buffer.write_string_utf16be(src)
    UTF16 | UTF16LE => buffer.write_string_utf16le(src)
  }
}

///|
/// Converts a Char to UTF-8 bytes.
///
/// Note that this function incurs allocation overhead
/// due to the intermediate creation of new buffers.
pub fn to_utf8_bytes(value : Char) -> Bytes {
  let buf = Buffer(size_hint=4)
  buf.write_char_utf8(value)
  buf.to_bytes()
}

///|
/// Converts a Char to UTF-16LE bytes.
///
/// Alias for `to_utf16le_bytes`.
///
/// Note that this function incurs allocation overhead
/// due to the intermediate creation of new buffers.
#deprecated("Use `to_utf16le_bytes` instead")
pub fn to_utf16_bytes(value : Char) -> Bytes {
  to_utf16le_bytes(value)
}

///|
/// Converts a Char to UTF-16LE bytes.
///
/// Note that this function incurs allocation overhead
/// due to the intermediate creation of new buffers.
pub fn to_utf16le_bytes(value : Char) -> Bytes {
  let buf = Buffer(size_hint=4)
  buf.write_char_utf16le(value)
  buf.to_bytes()
}

///|
/// Converts a Char to UTF-16BE bytes.
///
/// Note that this function incurs allocation overhead
/// due to the intermediate creation of new buffers.
pub fn to_utf16be_bytes(value : Char) -> Bytes {
  let buf = Buffer(size_hint=4)
  buf.write_char_utf16be(value)
  buf.to_bytes()
}

///|
/// Write a char into buffer as UTF8.
#deprecated("Use `buf.write_char_utf8(value)` instead")
pub fn write_utf8_char(buf : @buffer.Buffer, value : Char) -> Unit {
  buf.write_char_utf8(value)
}

///|
/// Write a char into buffer as UTF16LE.
/// Alias for `write_utf16le_char`
#deprecated("Use `buf.write_char_utf16le(value)` instead")
pub fn write_utf16_char(buf : @buffer.Buffer, value : Char) -> Unit {
  buf.write_char_utf16le(value)
}

///|
/// Write a char into buffer as UTF16LE.
#deprecated("Use `buf.write_char_utf16le(value)` instead")
pub fn write_utf16le_char(buf : @buffer.Buffer, value : Char) -> Unit {
  buf.write_char_utf16le(value)
}

///|
/// Write a char into buffer as UTF16BE.
#deprecated("Use `buf.write_char_utf16be(value)` instead")
pub fn write_utf16be_char(buf : @buffer.Buffer, value : Char) -> Unit {
  buf.write_char_utf16be(value)
}

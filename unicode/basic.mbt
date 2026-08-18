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
fn Char::shift_char(c : Char, delta : Int) -> Char {
  Int::to_char(c.to_int() + delta).unwrap()
}

///|
/// Combine a UTF-16 leading surrogate `hi` and trailing surrogate `lo` into
/// a char, or `None` if the code units are not a valid surrogate pair.
pub fn utf16_pair_to_char(hi : Int, lo : Int) -> Char? {
  guard hi.is_leading_surrogate() && lo.is_trailing_surrogate() else { None }
  Some(Int::unsafe_to_char((hi << 10) + lo - 0x35fdc00))
}

///|
/// Split a supplementary (astral) char into its UTF-16 leading and trailing
/// surrogate code units, or `None` if the char fits in a single code unit.
pub fn char_to_utf16_pair(ch : Char) -> (Int, Int)? {
  let c = ch.to_int()
  if c > 0xFFFF {
    let v = c - 0x10000
    Some((0xD800 + (v >> 10), 0xDC00 + (v & 0x3FF)))
  } else {
    None
  }
}

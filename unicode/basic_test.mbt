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
test "from_utf16_pair combines a valid surrogate pair" {
  debug_inspect(utf16_pair_to_char(0xD83D, 0xDE00), content="Some('😀')")
  debug_inspect(utf16_pair_to_char(0xD800, 0xDC00), content="Some('\u{10000}')")
  debug_inspect(
    utf16_pair_to_char(0xDBFF, 0xDFFF),
    content="Some('\\u{10ffff}')",
  )
}

///|
test "from_utf16_pair rejects invalid pairs" {
  debug_inspect(utf16_pair_to_char(0x0041, 0xDE00), content="None")
  debug_inspect(utf16_pair_to_char(0xD83D, 0x0041), content="None")
  debug_inspect(utf16_pair_to_char(0xD83D, 0xD83D), content="None")
}

///|
test "char_to_utf16_pair splits astral chars and rejects BMP chars" {
  debug_inspect(char_to_utf16_pair('😀'), content="Some((55357, 56832))")
  debug_inspect(char_to_utf16_pair('\u{10000}'), content="Some((55296, 56320))")
  debug_inspect(
    char_to_utf16_pair('\u{10ffff}'),
    content="Some((56319, 57343))",
  )
  debug_inspect(char_to_utf16_pair('A'), content="None")
}

///|
test "char_to_utf16_pair is the inverse of utf16_pair_to_char" {
  for ch in ['😀', '\u{10000}', '\u{10ffff}', '啊', 'A'] {
    if ch.to_int() > 0xFFFF {
      let (hi, lo) = char_to_utf16_pair(ch).unwrap()
      debug_inspect(utf16_pair_to_char(hi, lo) == Some(ch), content="true")
    }
  }
}

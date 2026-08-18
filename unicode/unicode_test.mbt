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
test "to_utf8_bytes encodes ASCII, BMP and astral chars" {
  debug_inspect(
    to_utf8_bytes("Hello"),
    content="<Bytes: [0x48, 0x65, 0x6c, 0x6c, 0x6f]>",
  )
  debug_inspect(
    to_utf8_bytes("α啊😦"),
    content="<Bytes: [0xce, 0xb1, 0xe5, 0x95, 0x8a, 0xf0, 0x9f, 0x98, 0xa6]>",
  )
}

///|
test "to_utf8_string decodes ASCII, BMP and astral chars" {
  debug_inspect(to_utf8_string(b"Hello"), content="\"Hello\"")
  debug_inspect(
    to_utf8_string(b"\xCE\xB1\xE5\x95\x8A\xF0\x9F\x98\xA6"),
    content="\"α啊😦\"",
  )
}

///|
test "to_utf8_bytes and to_utf8_string are inverse for astral pairs" {
  for s in ["😀", "\u{10000}\u{10ffff}", "hello 😦 世界"] {
    debug_inspect(to_utf8_string(to_utf8_bytes(s)) == s, content="true")
  }
}

///|
test "to_utf8_string truncates incomplete trailing sequences" {
  debug_inspect(to_utf8_string(b"\xE5\x95"), content="\"\"")
  debug_inspect(to_utf8_string(b"\xF0\x9F\x98"), content="\"\"")
}

///|
test "CharClass::contains checks ranges" {
  let cl = CharClass::of([('a', 'z'), ('あ', 'ん')])
  debug_inspect(cl.contains('m'), content="true")
  debug_inspect(cl.contains('A'), content="false")
  debug_inspect(cl.contains('い'), content="true")
  debug_inspect(cl.contains('ア'), content="false")
}

///|
fn linear_contains(pairs : Array[(Char, Char)], c : Char) -> Bool {
  for item in pairs {
    let (min, max) = item
    if c >= min && c <= max {
      return true
    }
  }
  false
}

///|
test "CharClass::of matches linear scan over the whole code space" {
  let pairs = [
    ('\u{1F}', '\u{20}'),
    ('\u{3F}', '\u{40}'),
    ('a', 'z'),
    ('\u{FFFF}', '\u{10000}'),
    ('\u{10001}', '\u{1000F}'),
    ('\u{1F600}', '\u{1F64F}'),
  ]
  let cl = CharClass::of(pairs)
  for code in 0..<0x110000 {
    if code >= 0xD800 && code <= 0xDFFF {
      continue
    }
    let c = code.to_char().unwrap()
    if cl.contains(c) != linear_contains(pairs, c) {
      debug_inspect(code, content="-2")
      return
    }
  }
}

///|
test "non_ascii tables classify chars per the JSON5 spec" {
  debug_inspect(non_ascii_whitespace.contains('\u{00A0}'), content="true")
  debug_inspect(non_ascii_whitespace.contains('\u{2003}'), content="true")
  debug_inspect(non_ascii_whitespace.contains('a'), content="false")
  debug_inspect(non_ascii_id_start.contains('α'), content="true")
  debug_inspect(non_ascii_id_start.contains('あ'), content="true")
  debug_inspect(non_ascii_id_start.contains('1'), content="false")
}

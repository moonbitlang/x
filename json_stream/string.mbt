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
fn parse_string_body(parser : StreamParser) -> String raise @json.ParseError {
  let buffer = StringBuilder()
  for ;; {
    let position = parser.position()
    match parser.advance() {
      Some('"') => break
      Some('\\') => parse_string_escape(parser, position, buffer)
      Some(c) =>
        if c < ' ' {
          invalid_char(position, c)
        } else {
          buffer.write_char(c)
        }
      None => raise @json.InvalidEof
    }
  }
  buffer.to_string()
}

///|
fn parse_string_escape(
  parser : StreamParser,
  escape_position : @json.Position,
  buffer : StringBuilder,
) -> Unit raise @json.ParseError {
  let position = parser.position()
  match parser.advance() {
    Some('b') => buffer.write_char('\b')
    Some('f') => buffer.write_char('\u{0C}')
    Some('n') => buffer.write_char('\n')
    Some('r') => buffer.write_char('\r')
    Some('t') => buffer.write_char('\t')
    Some('"') => buffer.write_char('"')
    Some('\\') => buffer.write_char('\\')
    Some('/') => buffer.write_char('/')
    Some('u') => parse_unicode_escape(parser, escape_position, buffer)
    Some(c) => invalid_char(position, c)
    None => raise @json.InvalidEof
  }
}

///|
fn parse_unicode_escape(
  parser : StreamParser,
  escape_position : @json.Position,
  buffer : StringBuilder,
) -> Unit raise @json.ParseError {
  let first = parse_hex_quad(parser)
  if first >= 0xD800 && first <= 0xDBFF {
    match parser.peek() {
      Some('\\') => ignore(parser.advance())
      _ => invalid_char(escape_position, '\\')
    }
    match parser.peek() {
      Some('u') => ignore(parser.advance())
      _ => invalid_char(escape_position, '\\')
    }
    let second = parse_hex_quad(parser)
    if second < 0xDC00 || second > 0xDFFF {
      invalid_char(escape_position, '\\')
    }
    let code_point = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
    buffer.write_char(code_point.unsafe_to_char())
  } else if first >= 0xDC00 && first <= 0xDFFF {
    invalid_char(escape_position, '\\')
  } else {
    buffer.write_char(first.unsafe_to_char())
  }
}

///|
fn parse_hex_quad(parser : StreamParser) -> Int32 raise @json.ParseError {
  let mut value = 0
  for _ in 0..<4 {
    let position = parser.position()
    match parser.advance() {
      Some(c) =>
        if is_hex_digit(c) {
          value = (value << 4) | hex_value(c)
        } else {
          invalid_char(position, c)
        }
      None => raise @json.InvalidEof
    }
  }
  value
}

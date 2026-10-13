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
fn parse_number(
  parser : StreamParser,
  start : @json.Position,
  first : Char,
) -> Json raise @json.ParseError {
  let buffer = StringBuilder()
  buffer.write_char(first)
  if first == '-' {
    parse_integer_digits(parser, buffer)
  } else if first == '0' {
    reject_leading_zero_digit(parser)
  } else {
    parse_integer_tail(parser, buffer)
  }
  parse_fraction(parser, buffer)
  parse_exponent(parser, buffer)
  let text = buffer.to_string()
  @json.parse(text) catch {
    _ => raise @json.InvalidNumber(start, text)
  }
}

///|
fn parse_integer_digits(
  parser : StreamParser,
  buffer : StringBuilder,
) -> Unit raise @json.ParseError {
  let position = parser.position()
  match parser.advance() {
    Some('0') => {
      buffer.write_char('0')
      reject_leading_zero_digit(parser)
    }
    Some(c) =>
      if is_nonzero_digit(c) {
        buffer.write_char(c)
        parse_integer_tail(parser, buffer)
      } else {
        invalid_char(position, c)
      }
    None => raise @json.InvalidEof
  }
}

///|
fn parse_integer_tail(parser : StreamParser, buffer : StringBuilder) -> Unit {
  for ;; {
    match parser.peek() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          ignore(parser.advance())
          continue
        } else {
          break
        }
      None => break
    }
  }
}

///|
fn reject_leading_zero_digit(
  parser : StreamParser,
) -> Unit raise @json.ParseError {
  match parser.peek() {
    Some(c) => if is_digit(c) { invalid_char(parser.position(), c) }
    None => ()
  }
}

///|
fn parse_fraction(
  parser : StreamParser,
  buffer : StringBuilder,
) -> Unit raise @json.ParseError {
  match parser.peek() {
    Some('.') => {
      buffer.write_char('.')
      ignore(parser.advance())
      let position = parser.position()
      match parser.advance() {
        Some(c) =>
          if is_digit(c) {
            buffer.write_char(c)
            parse_fraction_tail(parser, buffer)
          } else {
            invalid_char(position, c)
          }
        None => raise @json.InvalidEof
      }
    }
    _ => ()
  }
}

///|
fn parse_fraction_tail(parser : StreamParser, buffer : StringBuilder) -> Unit {
  for ;; {
    match parser.peek() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          ignore(parser.advance())
          continue
        } else {
          break
        }
      None => break
    }
  }
}

///|
fn parse_exponent(
  parser : StreamParser,
  buffer : StringBuilder,
) -> Unit raise @json.ParseError {
  match parser.peek() {
    Some('e' | 'E' as marker) => {
      buffer.write_char(marker)
      ignore(parser.advance())
      match parser.peek() {
        Some('+' | '-' as sign) => {
          buffer.write_char(sign)
          ignore(parser.advance())
        }
        _ => ()
      }
      let position = parser.position()
      match parser.advance() {
        Some(c) =>
          if is_digit(c) {
            buffer.write_char(c)
            parse_exponent_tail(parser, buffer)
          } else {
            invalid_char(position, c)
          }
        None => raise @json.InvalidEof
      }
    }
    _ => ()
  }
}

///|
fn parse_exponent_tail(parser : StreamParser, buffer : StringBuilder) -> Unit {
  for ;; {
    match parser.peek() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          ignore(parser.advance())
          continue
        } else {
          break
        }
      None => break
    }
  }
}

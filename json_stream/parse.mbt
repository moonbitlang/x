// Copyright 2026 International Digital Economy Academy
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
/// Parse one JSON document from a character iterator.
///
/// The iterator is consumed lazily. The parser keeps one character of
/// lookahead and only buffers the current string or number token, so callers do
/// not need to materialize the complete input as a `String` first.
///
/// Leading and trailing JSON whitespace are accepted. Additional non-whitespace
/// input after the document is rejected.
///
/// The returned value is the standard `moonbitlang/core/json.Json` type.
pub fn parse(
  input : Iter[Char],
  max_nesting_depth~ : Int32 = 1024,
) -> Json raise @json.ParseError {
  let parser = StreamParser::new(input)
  let value = parse_value(parser, max_nesting_depth)
  parser.skip_whitespace()
  match parser.peek() {
    Some(c) => invalid_char(parser.position(), c)
    None => value
  }
}

///|
/// Return whether the iterator contains one valid JSON document.
pub fn valid(input : Iter[Char]) -> Bool {
  try {
    ignore(parse(input))
    true
  } catch {
    _ => false
  }
}

///|
fn parse_value(
  parser : StreamParser,
  remaining_depth : Int32,
) -> Json raise @json.ParseError {
  parser.skip_whitespace()
  let position = parser.position()
  match parser.advance() {
    Some('{') => parse_object(parser, remaining_depth)
    Some('[') => parse_array(parser, remaining_depth)
    Some('"') => Json::string(parse_string_body(parser))
    Some('n') => parse_keyword(parser, "ull", Json::null())
    Some('t') => parse_keyword(parser, "rue", Json::boolean(true))
    Some('f') => parse_keyword(parser, "alse", Json::boolean(false))
    Some(c) =>
      if c == '-' || is_digit(c) {
        parse_number(parser, position, c)
      } else {
        invalid_char(position, c)
      }
    None => raise @json.InvalidEof
  }
}

///|
fn parse_keyword(
  parser : StreamParser,
  suffix : String,
  value : Json,
) -> Json raise @json.ParseError {
  for expected in suffix {
    parser.expect_char(expected)
  }
  value
}

///|
fn parse_object(
  parser : StreamParser,
  remaining_depth : Int32,
) -> Json raise @json.ParseError {
  if remaining_depth <= 0 {
    raise @json.DepthLimitExceeded
  }
  let child_depth = remaining_depth - 1
  let members : Map[String, Json] = Map([])
  parser.skip_whitespace()
  if parser.peek() is Some('}') {
    ignore(parser.advance())
    return Json::object(members)
  }
  for ;; {
    let position = parser.position()
    match parser.advance() {
      Some('"') => {
        let key = parse_string_body(parser)
        parser.skip_whitespace()
        parser.expect_char(':')
        members[key] = parse_value(parser, child_depth)
        parser.skip_whitespace()
        let separator_position = parser.position()
        match parser.advance() {
          Some(',') => {
            parser.skip_whitespace()
            continue
          }
          Some('}') => break
          Some(c) => invalid_char(separator_position, c)
          None => raise @json.InvalidEof
        }
      }
      Some(c) => invalid_char(position, c)
      None => raise @json.InvalidEof
    }
  }
  Json::object(members)
}

///|
fn parse_array(
  parser : StreamParser,
  remaining_depth : Int32,
) -> Json raise @json.ParseError {
  if remaining_depth <= 0 {
    raise @json.DepthLimitExceeded
  }
  let child_depth = remaining_depth - 1
  let elements : Array[Json] = []
  parser.skip_whitespace()
  if parser.peek() is Some(']') {
    ignore(parser.advance())
    return Json::array(elements)
  }
  for ;; {
    elements.push(parse_value(parser, child_depth))
    parser.skip_whitespace()
    let position = parser.position()
    match parser.advance() {
      Some(',') => {
        parser.skip_whitespace()
        continue
      }
      Some(']') => break
      Some(c) => invalid_char(position, c)
      None => raise @json.InvalidEof
    }
  }
  Json::array(elements)
}

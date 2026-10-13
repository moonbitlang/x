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
priv struct StreamParser {
  input : Iter[Char]
  mut lookahead : Char?
  mut reached_eof : Bool
  mut line : Int32
  mut column : Int32
}

///|
fn StreamParser::new(input : Iter[Char]) -> StreamParser {
  { input, lookahead: None, reached_eof: false, line: 1, column: 0, }
}

///|
fn StreamParser::position(self : StreamParser) -> @json.Position {
  { line: self.line, column: self.column, }
}

///|
fn StreamParser::peek(self : StreamParser) -> Char? {
  if self.reached_eof {
    return None
  }
  match self.lookahead {
    Some(c) => Some(c)
    None =>
      match self.input.next() {
        Some(c) => {
          self.lookahead = Some(c)
          Some(c)
        }
        None => {
          self.reached_eof = true
          None
        }
      }
  }
}

///|
fn StreamParser::advance(self : StreamParser) -> Char? {
  match self.peek() {
    Some(c) => {
      self.lookahead = None
      if c == '\n' {
        self.line += 1
        self.column = 0
      } else {
        self.column += 1
      }
      Some(c)
    }
    None => None
  }
}

///|
fn StreamParser::skip_whitespace(self : StreamParser) -> Unit {
  for ;; {
    match self.peek() {
      Some(' ' | '\t' | '\r' | '\n') => {
        ignore(self.advance())
        continue
      }
      _ => break
    }
  }
}

///|
fn StreamParser::expect_char(
  self : StreamParser,
  expected : Char,
) -> Unit raise @json.ParseError {
  let position = self.position()
  match self.advance() {
    Some(c) => if c != expected { invalid_char(position, c) }
    None => raise @json.InvalidEof
  }
}

///|
fn[T] invalid_char(
  position : @json.Position,
  c : Char,
) -> T raise @json.ParseError {
  raise @json.InvalidChar(position, c)
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_nonzero_digit(c : Char) -> Bool {
  c >= '1' && c <= '9'
}

///|
fn is_hex_digit(c : Char) -> Bool {
  is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn hex_value(c : Char) -> Int32 {
  if c >= '0' && c <= '9' {
    c.to_int() - '0'.to_int()
  } else if c >= 'a' && c <= 'f' {
    c.to_int() - 'a'.to_int() + 10
  } else {
    c.to_int() - 'A'.to_int() + 10
  }
}

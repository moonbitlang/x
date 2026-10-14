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
/// A JSON token or structural event produced by `Parser::next`.
pub(all) enum Event {
  StartObject
  EndObject
  StartArray
  EndArray
  Key(String)
  StringValue(String)
  NumberValue(Double, String?)
  BooleanValue(Bool)
  NullValue
}

///|
/// One pull step from a resumable JSON parser.
pub(all) enum ParseStep {
  Event(Event)
  NeedMoreInput
  Done
}

///|
priv enum FrameKind {
  ObjectFrame
  ArrayFrame
}

///|
priv enum ObjectState {
  ObjectFirstKeyOrEnd
  ObjectKey
  ObjectColon
  ObjectValue
  ObjectCommaOrEnd
}

///|
priv enum ArrayState {
  ArrayFirstValueOrEnd
  ArrayValue
  ArrayCommaOrEnd
}

///|
priv struct Frame {
  kind : FrameKind
  mut object_state : ObjectState
  mut array_state : ArrayState
}

///|
priv struct ParserCursor {
  chunk_index : Int32
  chunk_offset : Int32
  line : Int32
  column : Int32
}

///|
/// A pull-based JSON parser whose input can arrive in arbitrarily many chunks.
///
/// `feed` appends a chunk. `next` returns one event, `NeedMoreInput` when the
/// current chunk is exhausted before a token is complete, or `Done` after the
/// root value. Call `feed(..., eof=true)` to declare final end of input; this
/// distinguishes a temporary chunk boundary from an actual truncated document.
pub struct Parser {
  priv mut chunks : Array[String]
  priv mut chunk_index : Int32
  priv mut chunk_offset : Int32
  priv mut line : Int32
  priv mut column : Int32
  priv stack : Array[Frame]
  priv mut root_done : Bool
  priv mut final_eof : Bool
  priv max_nesting_depth : Int32
}

///|
pub fn Parser::new(max_nesting_depth~ : Int32 = 1024) -> Parser {
  {
    chunks: [],
    chunk_index: 0,
    chunk_offset: 0,
    line: 1,
    column: 0,
    stack: [],
    root_done: false,
    final_eof: false,
    max_nesting_depth,
  }
}

///|
/// Append a chunk to the parser.
///
/// A chunk must end on a Unicode scalar boundary. Chunks may end in the middle
/// of a token; the parser retains the unfinished token until the next `feed`.
pub fn Parser::feed(
  self : Parser,
  chunk : StringView,
  eof~ : Bool = false,
) -> Unit {
  if self.final_eof {
    return
  }
  self.compact()
  if chunk.length() > 0 {
    self.chunks.push(chunk.to_owned())
  }
  if eof {
    self.final_eof = true
  }
}

///|
fn Parser::compact(self : Parser) -> Unit {
  if self.chunk_index > 0 {
    self.chunks = self.chunks[self.chunk_index:].to_owned()
    self.chunk_index = 0
  }
}

///|
/// Pull the next event from the parser.
pub fn Parser::next(self : Parser) -> ParseStep raise @json.ParseError {
  for ;; {
    if self.root_done {
      self.skip_whitespace()
      match self.peek() {
        None => return Done
        Some(c) => invalid_char(self.position(), c)
      }
    }
    match self.current_frame() {
      None => return self.parse_value_event()
      Some(frame) =>
        match frame.kind {
          ObjectFrame =>
            match frame.object_state {
              ObjectFirstKeyOrEnd => {
                self.skip_whitespace()
                match self.peek() {
                  Some('}') => {
                    ignore(self.advance())
                    ignore(self.stack.pop())
                    self.finish_value()
                    return Event(EndObject)
                  }
                  Some('"') => return self.parse_key_event()
                  Some(c) => invalid_char(self.position(), c)
                  None => return self.missing_input()
                }
              }
              ObjectKey => return self.parse_key_event()
              ObjectColon => {
                self.skip_whitespace()
                match self.advance() {
                  Some(':') => {
                    frame.object_state = ObjectValue
                    continue
                  }
                  Some(c) => invalid_char(self.position(), c)
                  None => return self.missing_input()
                }
              }
              ObjectValue => return self.parse_value_event()
              ObjectCommaOrEnd => {
                self.skip_whitespace()
                match self.advance() {
                  Some(',') => {
                    frame.object_state = ObjectKey
                    continue
                  }
                  Some('}') => {
                    ignore(self.stack.pop())
                    self.finish_value()
                    return Event(EndObject)
                  }
                  Some(c) => invalid_char(self.position(), c)
                  None => return self.missing_input()
                }
              }
            }
          ArrayFrame =>
            match frame.array_state {
              ArrayFirstValueOrEnd => {
                self.skip_whitespace()
                match self.peek() {
                  Some(']') => {
                    ignore(self.advance())
                    ignore(self.stack.pop())
                    self.finish_value()
                    return Event(EndArray)
                  }
                  _ => return self.parse_value_event()
                }
              }
              ArrayValue => return self.parse_value_event()
              ArrayCommaOrEnd => {
                self.skip_whitespace()
                match self.advance() {
                  Some(',') => {
                    frame.array_state = ArrayValue
                    continue
                  }
                  Some(']') => {
                    ignore(self.stack.pop())
                    self.finish_value()
                    return Event(EndArray)
                  }
                  Some(c) => invalid_char(self.position(), c)
                  None => return self.missing_input()
                }
              }
            }
        }
    }
  }
}

///|
fn Parser::current_frame(self : Parser) -> Frame? {
  if self.stack.length() == 0 {
    None
  } else {
    Some(self.stack[self.stack.length() - 1])
  }
}

///|
fn Parser::finish_value(self : Parser) -> Unit {
  if self.stack.length() == 0 {
    self.root_done = true
    return
  }
  let frame = self.stack[self.stack.length() - 1]
  match frame.kind {
    ObjectFrame => frame.object_state = ObjectCommaOrEnd
    ArrayFrame => frame.array_state = ArrayCommaOrEnd
  }
}

///|
fn Parser::parse_key_event(self : Parser) -> ParseStep raise @json.ParseError {
  let cursor = self.cursor()
  let position = self.position()
  match self.advance() {
    Some('"') =>
      match self.scan_string_token(cursor) {
        Some(token) =>
          match @json.parse(token) {
            Json::String(key) => {
              let frame = self.stack[self.stack.length() - 1]
              frame.object_state = ObjectColon
              return Event(Key(key))
            }
            _ => abort("json string token did not parse as a string")
          }
        None => return NeedMoreInput
      }
    Some(c) => invalid_char(position, c)
    None => self.missing_input()
  }
}

///|
fn Parser::parse_value_event(self : Parser) -> ParseStep raise @json.ParseError {
  self.skip_whitespace()
  let cursor = self.cursor()
  let position = self.position()
  match self.advance() {
    Some('{') => {
      self.push_frame(ObjectFrame)
      return Event(StartObject)
    }
    Some('[') => {
      self.push_frame(ArrayFrame)
      return Event(StartArray)
    }
    Some('"') =>
      match self.scan_string_token(cursor) {
        Some(token) => {
          let value = @json.parse(token)
          match value {
            Json::String(text) => {
              self.finish_value()
              return Event(StringValue(text))
            }
            _ => abort("json string token did not parse as a string")
          }
        }
        None => return NeedMoreInput
      }
    Some('n') =>
      match self.consume_keyword("ull") {
        true => {
          self.finish_value()
          return Event(NullValue)
        }
        false => {
          self.restore(cursor)
          return NeedMoreInput
        }
      }
    Some('t') =>
      match self.consume_keyword("rue") {
        true => {
          self.finish_value()
          return Event(BooleanValue(true))
        }
        false => {
          self.restore(cursor)
          return NeedMoreInput
        }
      }
    Some('f') =>
      match self.consume_keyword("alse") {
        true => {
          self.finish_value()
          return Event(BooleanValue(false))
        }
        false => {
          self.restore(cursor)
          return NeedMoreInput
        }
      }
    Some(c) =>
      if c == '-' || is_digit(c) {
        match self.scan_number_token(cursor, c) {
          Some(token) =>
            match @json.parse(token) {
              Json::Number(number, repr~) => {
                self.finish_value()
                return Event(NumberValue(number, repr))
              }
              _ => abort("json number token did not parse as a number")
            }
          None => return NeedMoreInput
        }
      } else {
        invalid_char(position, c)
      }
    None => self.missing_input()
  }
}

///|
fn Parser::push_frame(
  self : Parser,
  kind : FrameKind,
) -> Unit raise @json.ParseError {
  if self.stack.length() >= self.max_nesting_depth {
    raise @json.DepthLimitExceeded
  }
  self.stack.push({
    kind,
    object_state: ObjectFirstKeyOrEnd,
    array_state: ArrayFirstValueOrEnd,
  })
}

///|
fn Parser::missing_input(self : Parser) -> ParseStep raise @json.ParseError {
  if self.final_eof {
    raise @json.InvalidEof
  }
  NeedMoreInput
}

///|
fn Parser::peek(self : Parser) -> Char? {
  for ;; {
    if self.chunk_index >= self.chunks.length() {
      return None
    }
    let chunk = self.chunks[self.chunk_index]
    if self.chunk_offset < chunk.length() {
      match chunk.get_char(self.chunk_offset) {
        Some(c) => return Some(c)
        None => return None
      }
    } else {
      self.chunk_index += 1
      self.chunk_offset = 0
    }
  }
}

///|
fn Parser::advance(self : Parser) -> Char? {
  match self.peek() {
    Some(c) => {
      self.chunk_offset += c.utf16_len()
      if self.chunk_offset >= self.chunks[self.chunk_index].length() {
        self.chunk_index += 1
        self.chunk_offset = 0
      }
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
fn Parser::skip_whitespace(self : Parser) -> Unit {
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
fn Parser::position(self : Parser) -> @json.Position {
  { line: self.line, column: self.column, }
}

///|
fn Parser::cursor(self : Parser) -> ParserCursor {
  {
    chunk_index: self.chunk_index,
    chunk_offset: self.chunk_offset,
    line: self.line,
    column: self.column,
  }
}

///|
fn Parser::restore(self : Parser, cursor : ParserCursor) -> Unit {
  self.chunk_index = cursor.chunk_index
  self.chunk_offset = cursor.chunk_offset
  self.line = cursor.line
  self.column = cursor.column
}

///|
fn Parser::consume_keyword(
  self : Parser,
  suffix : String,
) -> Bool raise @json.ParseError {
  let cursor = self.cursor()
  for expected in suffix {
    let position = self.position()
    match self.advance() {
      Some(c) => if c != expected { invalid_char(position, c) }
      None => {
        if self.final_eof {
          raise @json.InvalidEof
        }
        self.restore(cursor)
        return false
      }
    }
  }
  true
}

///|
fn Parser::scan_string_token(
  self : Parser,
  start_cursor : ParserCursor,
) -> String? raise @json.ParseError {
  let buffer = StringBuilder()
  buffer.write_char('"')
  for ;; {
    let position = self.position()
    match self.advance() {
      Some('"') => {
        buffer.write_char('"')
        return Some(buffer.to_string())
      }
      Some('\\') => {
        buffer.write_char('\\')
        match self.advance() {
          Some(c) => {
            buffer.write_char(c)
            if c == 'u' {
              for _ in 0..<4 {
                match self.advance() {
                  Some(hex) => buffer.write_char(hex)
                  None => {
                    if self.final_eof {
                      raise @json.InvalidEof
                    }
                    self.restore(start_cursor)
                    return None
                  }
                }
              }
            }
          }
          None => {
            if self.final_eof {
              raise @json.InvalidEof
            }
            self.restore(start_cursor)
            return None
          }
        }
      }
      Some(c) =>
        if c < ' ' {
          invalid_char(position, c)
        } else {
          buffer.write_char(c)
        }
      None => {
        if self.final_eof {
          raise @json.InvalidEof
        }
        self.restore(start_cursor)
        return None
      }
    }
  }
}

///|
fn Parser::scan_number_token(
  self : Parser,
  start_cursor : ParserCursor,
  first : Char,
) -> String? raise @json.ParseError {
  let buffer = StringBuilder()
  buffer.write_char(first)
  if first == '-' {
    match self.advance() {
      Some('0') => {
        buffer.write_char('0')
        if self.peek() is Some(c) && is_digit(c) {
          invalid_char(self.position(), c)
        }
      }
      Some(c) =>
        if is_nonzero_digit(c) {
          buffer.write_char(c)
          self.scan_number_digits(buffer)
        } else {
          invalid_char(self.position(), c)
        }
      None => {
        if self.final_eof {
          raise @json.InvalidEof
        }
        self.restore(start_cursor)
        return None
      }
    }
  } else if first == '0' {
    if self.peek() is Some(c) && is_digit(c) {
      invalid_char(self.position(), c)
    }
  } else {
    self.scan_number_digits(buffer)
  }
  if self.peek() is Some('.') {
    ignore(self.advance())
    buffer.write_char('.')
    let position = self.position()
    match self.advance() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          self.scan_number_digits(buffer)
        } else {
          invalid_char(position, c)
        }
      None => {
        if self.final_eof {
          raise @json.InvalidEof
        }
        self.restore(start_cursor)
        return None
      }
    }
  }
  if self.peek() is Some('e' | 'E' as marker) {
    ignore(self.advance())
    buffer.write_char(marker)
    if self.peek() is Some('+' | '-' as sign) {
      ignore(self.advance())
      buffer.write_char(sign)
    }
    let position = self.position()
    match self.advance() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          self.scan_number_digits(buffer)
        } else {
          invalid_char(position, c)
        }
      None => {
        if self.final_eof {
          raise @json.InvalidEof
        }
        self.restore(start_cursor)
        return None
      }
    }
  }
  match self.peek() {
    None =>
      if self.final_eof {
        Some(buffer.to_string())
      } else {
        self.restore(start_cursor)
        None
      }
    Some(c) =>
      if c == ' ' ||
        c == '\t' ||
        c == '\r' ||
        c == '\n' ||
        c == ',' ||
        c == ']' ||
        c == '}' {
        Some(buffer.to_string())
      } else {
        invalid_char(self.position(), c)
      }
  }
}

///|
fn Parser::scan_number_digits(self : Parser, buffer : StringBuilder) -> Unit {
  for ;; {
    match self.peek() {
      Some(c) =>
        if is_digit(c) {
          buffer.write_char(c)
          ignore(self.advance())
          continue
        } else {
          break
        }
      None => break
    }
  }
}

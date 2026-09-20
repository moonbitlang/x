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
priv struct FooterParser {
  bytes : BytesView
  base : Int
  version : Version
  mut pos : Int
}

///|
fn FooterParser::designation(self : FooterParser) -> String raise ParseError {
  let quoted = self.bytes.get(self.pos) == Some(b'<')
  if quoted {
    self.pos += 1
  }
  let start = self.pos
  let name = StringBuilder()
  while self.bytes.get(self.pos) is Some(byte) {
    let letter = byte is (b'A'..=b'Z' | b'a'..=b'z')
    if !(letter || (quoted && byte is (b'0'..=b'9' | b'+' | b'-'))) {
      break
    }
    name.write_char(byte.to_int().unsafe_to_char())
    self.pos += 1
  }
  guard self.pos - start >= 3 else {
    raise ParseError(
      self.base + start,
      "footer designation must contain at least three characters",
    )
  }
  if quoted {
    self.expect(b'>')
  }
  name.to_string()
}

///|
fn FooterParser::expect(
  self : FooterParser,
  byte : Byte,
) -> Unit raise ParseError {
  guard self.bytes.get(self.pos) == Some(byte) else {
    raise ParseError(self.base + self.pos, "unexpected footer delimiter")
  }
  self.pos += 1
}

///|
fn FooterParser::number(
  self : FooterParser,
  minimum : Int,
  maximum : Int,
) -> Int raise ParseError {
  let start = self.pos
  let mut value = 0
  while self.bytes.get(self.pos) is Some(byte) && byte is (b'0'..=b'9') {
    let digit = byte.to_int() - b'0'.to_int()
    guard value <= (maximum - digit) / 10 else {
      raise ParseError(self.base + start, "footer number out of range")
    }
    value = value * 10 + digit
    guard value <= maximum else {
      raise ParseError(self.base + start, "footer number out of range")
    }
    self.pos += 1
  }
  guard self.pos > start && value >= minimum else {
    raise ParseError(self.base + start, "missing or out-of-range footer number")
  }
  value
}

///|
fn FooterParser::clock(
  self : FooterParser,
  maximum_hour : Int,
  signed : Bool,
) -> Int raise ParseError {
  let sign = match self.bytes.get(self.pos) {
    Some(b'-') if signed => {
      self.pos += 1
      -1
    }
    Some(b'+') if signed => {
      self.pos += 1
      1
    }
    _ => 1
  }
  let hours = self.number(0, maximum_hour)
  let minutes = if self.bytes.get(self.pos) == Some(b':') {
    self.pos += 1
    self.number(0, 59)
  } else {
    0
  }
  let seconds = if self.bytes.get(self.pos) == Some(b':') {
    self.pos += 1
    self.number(0, 59)
  } else {
    0
  }
  sign * (hours * 3600 + minutes * 60 + seconds)
}

///|
fn FooterParser::rule(self : FooterParser) -> Rule raise ParseError {
  let day = match self.bytes.get(self.pos) {
    Some(b'J') => {
      self.pos += 1
      JulianNoLeap(self.number(1, 365))
    }
    Some(b'M') => {
      self.pos += 1
      let month = self.number(1, 12)
      self.expect(b'.')
      let week = self.number(1, 5)
      self.expect(b'.')
      let weekday = self.number(0, 6)
      MonthWeekDay(month~, week~, weekday~)
    }
    _ => DayOfYear(self.number(0, 365))
  }
  let time = if self.bytes.get(self.pos) == Some(b'/') {
    self.pos += 1
    let extended = self.version == V3 || self.version == V4
    self.clock(if extended { 167 } else { 24 }, extended)
  } else {
    7200
  }
  { day, time, }
}

///|
fn parse_footer(
  bytes : BytesView,
  base : Int,
  version : Version,
) -> PosixTz raise ParseError {
  let parser : FooterParser = { bytes, base, version, pos: 0, }
  let standard_designation = parser.designation()
  // POSIX spells the offset to add to local time to obtain UT, the opposite
  // of the offset in each TZif local time type. Normalize that sign here.
  let standard_offset = -parser.clock(24, true)
  let daylight = if parser.pos == bytes.length() {
    None
  } else {
    let designation = parser.designation()
    let offset = match bytes.get(parser.pos) {
      Some(b'0'..=b'9' | b'+' | b'-') => -parser.clock(24, true)
      _ => standard_offset + 3600
    }
    let rules = if bytes.get(parser.pos) == Some(b',') {
      parser.pos += 1
      let start = parser.rule()
      parser.expect(b',')
      let end = parser.rule()
      Some((start, end))
    } else {
      None
    }
    Some({ designation, offset, rules, })
  }
  guard parser.pos == bytes.length() else {
    raise ParseError(base + parser.pos, "trailing or invalid footer bytes")
  }
  { standard_designation, standard_offset, daylight, }
}

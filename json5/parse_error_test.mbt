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

//region errors

///|
fn parse_error(input : String) -> Error raise {
  @test.expect_error(() => @json5.parse(input))
}

///|
test "throws on empty documents" {
  debug_inspect(parse_error(""), content="Unexpected end of file")
}

///|
test "throws on documents with only comments" {
  debug_inspect(parse_error("//a"), content="Unexpected end of file")
}

///|
test "debug parse error data" {
  let pos : @json5.Position = { line: 1, column: 2 }
  let data : @json5.ParseErrorData = InvalidChar(pos, 'x')
  debug_inspect(data, content="InvalidChar({ line: 1, column: 2 }, 'x')")
}

///|
test "throws on incomplete single line comments" {
  debug_inspect(parse_error("/a"), content="No valid token at line 1, column 1")
}

///|
test "throws on unterminated multiline comments" {
  debug_inspect(parse_error("/*"), content="Unexpected end of file")
}

///|
test "throws on unterminated multiline comment closings" {
  debug_inspect(parse_error("/**"), content="Unexpected end of file")
}

///|
test "throws on invalid characters in values" {
  debug_inspect(parse_error("a"), content="No valid token at line 1, column 1")
}

///|
test "throws on invalid characters in identifier start escapes" {
  debug_inspect(
    parse_error("{\\a:1}"),
    content="Invalid character a at line 1, column 2",
  )
}

///|
test "throws on invalid characters in identifier continue escapes" {
  debug_inspect(
    parse_error("{a\\a:1}"),
    content="Invalid character a at line 1, column 3",
  )
}

///|
test "throws on invalid identifier continue characters" {
  debug_inspect(
    parse_error("{a\\u0021:1}"),
    content="Invalid escape sequence in identifier at line 1, column 2",
  )
}

///|
test "throws on invalid characters following a sign" {
  debug_inspect(parse_error("-a"), content="No valid token at line 1, column 1")
}

///|
test "throws on invalid characters following a leading decimal point" {
  debug_inspect(parse_error(".a"), content="No valid token at line 1, column 1")
}

///|
test "throws on invalid characters following an exponent indicator" {
  debug_inspect(
    parse_error("1ea"),
    content="Invalid character e at line 1, column 1",
  )
}

///|
test "throws on invalid characters following an exponent sign" {
  debug_inspect(
    parse_error("1e-a"),
    content="Invalid character e at line 1, column 1",
  )
}

///|
test "throws on number parse failures" {
  debug_inspect(
    parse_error("1e999999"),
    content="Invalid number 1e999999 at line 1, column 0",
  )
}

///|
test "throws on invalid characters following a hexadecimal indicator" {
  debug_inspect(
    parse_error("0xg"),
    content="Invalid character g at line 1, column 2",
  )
}

///|
test "throws on invalid new lines in strings" {
  debug_inspect(
    parse_error("\"\n\""),
    content=(
      #|Invalid character 
      #| at line 1, column 1
    ),
  )
}

///|
test "throws on unterminated strings" {
  debug_inspect(parse_error("\""), content="Unexpected end of file")
}

///|
test "throws on invalid identifier start characters in property names" {
  debug_inspect(
    parse_error("{!:1}"),
    content="Invalid character ! at line 1, column 1",
  )
}

///|
test "throws on invalid characters following a property name" {
  debug_inspect(
    parse_error("{a!1}"),
    content="Invalid character ! at line 1, column 2",
  )
}

///|
test "throws on invalid characters following a property value" {
  debug_inspect(
    parse_error("{a:1!}"),
    content="Invalid character ! at line 1, column 4",
  )
}

///|
test "throws on invalid characters following an array value" {
  debug_inspect(
    parse_error("[1!]"),
    content="Invalid character ! at line 1, column 2",
  )
}

///|
test "throws on invalid characters in literals" {
  debug_inspect(
    parse_error("tru!"),
    content="No valid token at line 1, column 1",
  )
}

///|
test "throws on unterminated escapes" {
  debug_inspect(parse_error("\"\\"), content="Unexpected end of file")
}

///|
test "throws on invalid first digits in hexadecimal escapes" {
  debug_inspect(
    parse_error("\"\\xg\""),
    content="Invalid character g at line 1, column 3",
  )
}

///|
test "throws on invalid second digits in hexadecimal escapes" {
  debug_inspect(
    parse_error("\"\\x0g\""),
    content="Invalid character g at line 1, column 4",
  )
}

///|
test "throws on invalid unicode escapes" {
  debug_inspect(
    parse_error("\"\\u000g\""),
    content="Invalid character g at line 1, column 6",
  )
}

///|
test "throws on escaped digits" {
  debug_inspect(
    parse_error("\"\\1\""),
    content="Invalid character 1 at line 1, column 2",
  )
}

///|
test "throws on octal escapes" {
  debug_inspect(
    parse_error("\"\\01\""),
    content="Invalid character 1 at line 1, column 3",
  )
}

///|
test "throws on multiple values" {
  debug_inspect(
    parse_error("1 2"),
    content="Invalid character 2 at line 1, column 2",
  )
}

///|
test "throws with control characters escaped in the message" {
  debug_inspect(
    parse_error("\u{01}"),
    content="No valid token at line 1, column 1",
  )
}

///|
test "throws on unclosed objects before property names" {
  debug_inspect(parse_error("{"), content="Unexpected end of file")
}

///|
test "throws on unclosed objects after property names" {
  debug_inspect(parse_error("{a"), content="Unexpected end of file")
}

///|
test "throws on unclosed objects before property values" {
  debug_inspect(parse_error("{a:"), content="Unexpected end of file")
}

///|
test "throws on unclosed objects after property values" {
  debug_inspect(parse_error("{a:1"), content="Unexpected end of file")
}

///|
test "throws on unclosed arrays before values" {
  debug_inspect(parse_error("["), content="Unexpected end of file")
}

///|
test "throws on unclosed arrays after values" {
  debug_inspect(parse_error("[1"), content="Unexpected end of file")
}
//endregion

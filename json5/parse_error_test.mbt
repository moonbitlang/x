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
test "throws on empty documents" {
  let res = try? @json5.parse("")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on documents with only comments" {
  let res = try? @json5.parse("//a")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "debug parse error data" {
  let pos : @json5.Position = { line: 1, column: 2 }
  let data : @json5.ParseErrorData = InvalidChar(pos, 'x')
  debug_inspect(data, content="InvalidChar({ line: 1, column: 2 }, 'x')")
}

///|
test "throws on incomplete single line comments" {
  let res = try? @json5.parse("/a")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on unterminated multiline comments" {
  let res = try? @json5.parse("/*")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unterminated multiline comment closings" {
  let res = try? @json5.parse("/**")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on invalid characters in values" {
  let res = try? @json5.parse("a")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on invalid characters in identifier start escapes" {
  let res = try? @json5.parse("{\\a:1}")
  debug_inspect(res, content="Err(Invalid character a at line 1, column 2)")
}

///|
test "throws on invalid characters in identifier continue escapes" {
  let res = try? @json5.parse("{a\\a:1}")
  debug_inspect(res, content="Err(Invalid character a at line 1, column 3)")
}

///|
test "throws on invalid identifier continue characters" {
  let res = try? @json5.parse("{a\\u0021:1}")
  debug_inspect(
    res,
    content="Err(Invalid escape sequence in identifier at line 1, column 2)",
  )
}

///|
test "throws on invalid characters following a sign" {
  let res = try? @json5.parse("-a")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on invalid characters following a leading decimal point" {
  let res = try? @json5.parse(".a")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on invalid characters following an exponent indicator" {
  let res = try? @json5.parse("1ea")
  debug_inspect(res, content="Err(Invalid character e at line 1, column 1)")
}

///|
test "throws on invalid characters following an exponent sign" {
  let res = try? @json5.parse("1e-a")
  debug_inspect(res, content="Err(Invalid character e at line 1, column 1)")
}

///|
test "throws on number parse failures" {
  let res = try? @json5.parse("1e999999")
  debug_inspect(res, content="Err(Invalid number 1e999999 at line 1, column 0)")
}

///|
test "throws on invalid characters following a hexadecimal indicator" {
  let res = try? @json5.parse("0xg")
  debug_inspect(res, content="Err(Invalid character g at line 1, column 2)")
}

///|
test "throws on invalid new lines in strings" {
  let res = try? @json5.parse("\"\n\"")
  debug_inspect(
    res,
    content=(
      #|Err(Invalid character 
      #| at line 1, column 1)
    ),
  )
}

///|
test "throws on unterminated strings" {
  let res = try? @json5.parse("\"")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on invalid identifier start characters in property names" {
  let res = try? @json5.parse("{!:1}")
  debug_inspect(res, content="Err(Invalid character ! at line 1, column 1)")
}

///|
test "throws on invalid characters following a property name" {
  let res = try? @json5.parse("{a!1}")
  debug_inspect(res, content="Err(Invalid character ! at line 1, column 2)")
}

///|
test "throws on invalid characters following a property value" {
  let res = try? @json5.parse("{a:1!}")
  debug_inspect(res, content="Err(Invalid character ! at line 1, column 4)")
}

///|
test "throws on invalid characters following an array value" {
  let res = try? @json5.parse("[1!]")
  debug_inspect(res, content="Err(Invalid character ! at line 1, column 2)")
}

///|
test "throws on invalid characters in literals" {
  let res = try? @json5.parse("tru!")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on unterminated escapes" {
  let res = try? @json5.parse("\"\\")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on invalid first digits in hexadecimal escapes" {
  let res = try? @json5.parse("\"\\xg\"")
  debug_inspect(res, content="Err(Invalid character g at line 1, column 3)")
}

///|
test "throws on invalid second digits in hexadecimal escapes" {
  let res = try? @json5.parse("\"\\x0g\"")
  debug_inspect(res, content="Err(Invalid character g at line 1, column 4)")
}

///|
test "throws on invalid unicode escapes" {
  let res = try? @json5.parse("\"\\u000g\"")
  debug_inspect(res, content="Err(Invalid character g at line 1, column 6)")
}

///|
test "throws on escaped digits" {
  let res = try? @json5.parse("\"\\1\"")
  debug_inspect(res, content="Err(Invalid character 1 at line 1, column 2)")
}

///|
test "throws on octal escapes" {
  let res = try? @json5.parse("\"\\01\"")
  debug_inspect(res, content="Err(Invalid character 1 at line 1, column 3)")
}

///|
test "throws on multiple values" {
  let res = try? @json5.parse("1 2")
  debug_inspect(res, content="Err(Invalid character 2 at line 1, column 2)")
}

///|
test "throws with control characters escaped in the message" {
  let res = try? @json5.parse("\u{01}")
  debug_inspect(res, content="Err(No valid token at line 1, column 1)")
}

///|
test "throws on unclosed objects before property names" {
  let res = try? @json5.parse("{")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unclosed objects after property names" {
  let res = try? @json5.parse("{a")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unclosed objects before property values" {
  let res = try? @json5.parse("{a:")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unclosed objects after property values" {
  let res = try? @json5.parse("{a:1")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unclosed arrays before values" {
  let res = try? @json5.parse("[")
  debug_inspect(res, content="Err(Unexpected end of file)")
}

///|
test "throws on unclosed arrays after values" {
  let res = try? @json5.parse("[1")
  debug_inspect(res, content="Err(Unexpected end of file)")
}
//endregion

// Copyright 2024 International Digital Economy Academy
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
test "throws on empty documents" {
  let res = @json5.parse?("")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on documents with only comments" {
  let res = @json5.parse?("//a")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on incomplete single line comments" {
  let res = @json5.parse?("/a")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 1 }, 'a')))
}

test "throws on unterminated multiline comments" {
  let res = @json5.parse?("/*")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unterminated multiline comment closings" {
  let res = @json5.parse?("/**")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on invalid characters in values" {
  let res = @json5.parse?("a")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 0 }, 'a')))
}

test "throws on invalid characters in identifier start escapes" {
  let res = @json5.parse?("{\\a:1}")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, 'a')))
}

test "throws on invalid characters in identifier continue escapes" {
  let res = @json5.parse?("{a\\a:1}")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 3 }, 'a')))
}

test "throws on invalid identifier continue characters" {
  let res = @json5.parse?("{a\\u0021:1}")
  @test.eq!(res, Err(InvalidIdentEscape({ line: 1, column: 2 })))
}

test "throws on invalid characters following a sign" {
  let res = @json5.parse?("-a")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 1 }, 'a')))
}

test "throws on invalid characters following a leading decimal point" {
  let res = @json5.parse?(".a")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 1 }, 'a')))
}

test "throws on invalid characters following an exponent indicator" {
  let res = @json5.parse?("1ea")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, 'a')))
}

test "throws on invalid characters following an exponent sign" {
  let res = @json5.parse?("1e-a")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 3 }, 'a')))
}

test "throws on invalid characters following a hexadecimal indicator" {
  let res = @json5.parse?("0xg")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, 'g')))
}

test "throws on invalid new lines in strings" {
  let res = @json5.parse?("\"\n\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 1 }, '\n')))
}

test "throws on unterminated strings" {
  let res = @json5.parse?("\"")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on invalid identifier start characters in property names" {
  let res = @json5.parse?("{!:1}")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 1 }, '!')))
}

test "throws on invalid characters following a property name" {
  let res = @json5.parse?("{a!1}")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, '!')))
}

test "throws on invalid characters following a property value" {
  let res = @json5.parse?("{a:1!}")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 4 }, '!')))
}

test "throws on invalid characters following an array value" {
  let res = @json5.parse?("[1!]")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, '!')))
}

test "throws on invalid characters in literals" {
  let res = @json5.parse?("tru!")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 3 }, '!')))
}

test "throws on unterminated escapes" {
  let res = @json5.parse?("\"\\")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on invalid first digits in hexadecimal escapes" {
  let res = @json5.parse?("\"\\xg\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 3 }, 'g')))
}

test "throws on invalid second digits in hexadecimal escapes" {
  let res = @json5.parse?("\"\\x0g\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 4 }, 'g')))
}

test "throws on invalid unicode escapes" {
  let res = @json5.parse?("\"\\u000g\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 6 }, 'g')))
}

test "throws on escaped digits" {
  let res = @json5.parse?("\"\\1\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, '1')))
}

test "throws on octal escapes" {
  let res = @json5.parse?("\"\\01\"")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 3 }, '1')))
}

test "throws on multiple values" {
  let res = @json5.parse?("1 2")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 2 }, '2')))
}

test "throws with control characters escaped in the message" {
  let res = @json5.parse?("\x01")
  @test.eq!(res, Err(InvalidChar({ line: 1, column: 0 }, '\x01')))
}

test "throws on unclosed objects before property names" {
  let res = @json5.parse?("{")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unclosed objects after property names" {
  let res = @json5.parse?("{a")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unclosed objects before property values" {
  let res = @json5.parse?("{a:")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unclosed objects after property values" {
  let res = @json5.parse?("{a:1")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unclosed arrays before values" {
  let res = @json5.parse?("[")
  @test.eq!(res, Err(InvalidEof))
}

test "throws on unclosed arrays after values" {
  let res = @json5.parse?("[1")
  @test.eq!(res, Err(InvalidEof))
}
//endregion

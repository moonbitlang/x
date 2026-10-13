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
fn parse_text(text : String) -> Json raise @json.ParseError {
  @json_stream.parse(text.iter())
}

///|
test "parses every primitive" {
  @debug.assert_eq(parse_text("null"), Json::null())
  @debug.assert_eq(parse_text("true"), Json::boolean(true))
  @debug.assert_eq(parse_text("false"), Json::boolean(false))
  @debug.assert_eq(parse_text("\"hello\""), Json::string("hello"))
  @debug.assert_eq(parse_text("42"), Json::number(42.0))
}

///|
test "matches the core parser for representative documents" {
  let inputs : Array[String] = [
    "{}", "[]", "{\"a\":1}", "[1,2,3]", "{\"nested\":[true,false,null,{\"negative\":-1}]}",
    "{\"empty_object\":{},\"empty_array\":[]}", "[[[[[[[[[[0]]]]]]]]]]", "[0.0,-0.0,1.5,-2.25,1e3,1E-3,1e+3]",
    "[-9223372036854775808,9223372036854775807]", "[1.7976931348623157e308,5e-324]",
    "\"\"", "\"\\\"\\\\\\/\\b\\f\\n\\r\\t\"", "\"\\u0000\\u001f\\u007f\"", "\"\\u20ac\"",
    "\"\\ud83d\\ude00\"", "{\"text\":\"line\\nfeed\"}", "{\"unicode\":\"\\u4e2d\\u6587\"}",
    "{\"surrogate\":\"\\ud83d\\ude00\"}", "{\"escaped\":\"\\u0022quoted\\u0022\"}",
    "{\"slash\":\"a\\/b\"}", "{\"duplicate\":1,\"duplicate\":2}", "999999999999999999999999999999",
    "-999999999999999999999999999999",
  ]
  for input in inputs {
    let expected = @json.parse(input)
    let actual = parse_text(input)
    @debug.assert_eq(actual, expected)
  }
}

///|
test "matches the core parser across ASCII strings" {
  for code_point in 0..<128 {
    let c = code_point.unsafe_to_char()
    if c != '"' && c != '\\' && c >= ' ' {
      let input = "\"" + c.to_string() + "\""
      @debug.assert_eq(parse_text(input), @json.parse(input))
    }
  }
}

///|
test "accepts surrounding whitespace" {
  @debug.assert_eq(
    parse_text(" \t\r\n {\"a\" : [1, 2, 3]} \n"),
    @json.parse("{\"a\":[1,2,3]}"),
  )
}

///|
test "preserves object member insertion order" {
  let json = parse_text("{\"z\":1,\"a\":2,\"m\":3}")
  inspect(json.stringify(), content="{\"z\":1,\"a\":2,\"m\":3}")
}

///|
test "parses deeply nested arrays within the limit" {
  let depth = 512
  let input = "[".repeat(depth) + "0" + "]".repeat(depth)
  let json = parse_text(input)
  let mut current = json
  for i in 0..<depth {
    guard current is Json::Array(values) else {
      fail("expected array at depth \{i}")
    }
    current = values[0]
  }
  @debug.assert_eq(current, Json::number(0.0))
}

///|
test "parses a large flat array lazily" {
  let size = 10000
  let input = "[" + Array::makei(size, i => i.to_string()).join(",") + "]"
  let json = parse_text(input)
  guard json is Json::Array(values) else { fail("expected array") }
  @debug.assert_eq(values.length(), size)
  @debug.assert_eq(values[0], Json::number(0.0))
  @debug.assert_eq(values[size - 1], Json::number((size - 1).to_double()))
}

///|
test "parses long strings without dropping chunks" {
  let chunk = "0123456789abcdef"
  let size = 4096
  let buffer = StringBuilder()
  for _ in 0..<size {
    buffer.write_string(chunk)
  }
  let text = buffer.to_string()
  let input = "\"" + text + "\""
  @debug.assert_eq(parse_text(input), Json::string(text))
}

///|
test "valid consumes an iterator" {
  inspect(@json_stream.valid("{\"ok\":true}".iter()), content="true")
  inspect(@json_stream.valid("[1,2,".iter()), content="false")
}

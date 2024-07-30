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

fn test_parse(input : String, ~loc : SourceLoc = _) -> @json.JsonValue!String {
  let v = @json5.parse?(input)
  match v {
    Ok(v) => v
    Err(err) => raise "Parse failed, \(loc), \(err)"
  }
}

//region objects
test "parses empty objects" {
  let json = test_parse!("{}")
  @test.eq!(json, @json.JsonValue::Object(Map::of([])))
}

test "parses double string property names" {
  let json = test_parse!("{\"a\":1}")
  @test.eq!(
    json,
    @json.JsonValue::Object(Map::of([("a", @json.JsonValue::Number(1.0))])),
  )
}

test "parses single string property names" {
  let json = test_parse!("{a:1}")
  @test.eq!(
    json,
    @json.JsonValue::Object(Map::of([("a", @json.JsonValue::Number(1.0))])),
  )
}

test "parses unquoted property names" {
  let json = test_parse!("{a:1}")
  @test.eq!(
    json,
    @json.JsonValue::Object(Map::of([("a", @json.JsonValue::Number(1.0))])),
  )
}

test "parses special character property names" {
  let json = test_parse!("{$_:1,_$:2,a\u200C:3}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of(
        [
          ("$_", @json.JsonValue::Number(1.0)),
          ("_$", @json.JsonValue::Number(2.0)),
          ("a\u200C", @json.JsonValue::Number(3.0)),
        ],
      ),
    ),
  )
}

test "parses unicode property names" {
  let json = test_parse!("{ùńîċõďë:9}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of([("ùńîċõďë", @json.JsonValue::Number(9.0))]),
    ),
  )
}

test "parses escaped property names" {
  let json = test_parse!("{\\u0061\\u0062:1,\\u0024\\u005F:2,\\u005F\\u0024:3}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of(
        [
          ("ab", @json.JsonValue::Number(1.0)),
          ("$_", @json.JsonValue::Number(2.0)),
          ("_$", @json.JsonValue::Number(3.0)),
        ],
      ),
    ),
  )
}

test "preserves __proto__ property names" {
  let json = test_parse!("{\"__proto__\":1}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of([("__proto__", @json.JsonValue::Number(1.0))]),
    ),
  )
}

test "parses multiple properties" {
  let json = test_parse!("{abc:1,def:2}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of(
        [
          ("abc", @json.JsonValue::Number(1.0)),
          ("def", @json.JsonValue::Number(2.0)),
        ],
      ),
    ),
  )
}

test "parses nested objects" {
  let json = test_parse!("{a:{b:2}}")
  @test.eq!(
    json,
    @json.JsonValue::Object(
      Map::of(
        [
          (
            "a",
            @json.JsonValue::Object(
              Map::of([("b", @json.JsonValue::Number(2.0))]),
            ),
          ),
        ],
      ),
    ),
  )
}
//endregion

//region arrays
test "parses empty arrays" {
  let json = test_parse!("[]")
  @test.eq!(json, @json.JsonValue::Array([]))
}

test "parses array values" {
  let json = test_parse!("[1]")
  @test.eq!(json, @json.JsonValue::Array([@json.JsonValue::Number(1.0)]))
}

test "parses multiple array values" {
  let json = test_parse!("[1,2]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [@json.JsonValue::Number(1.0), @json.JsonValue::Number(2.0)],
    ),
  )
}

test "parses nested arrays" {
  let json = test_parse!("[1,[2,3]]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(1.0),
        @json.JsonValue::Array(
          [@json.JsonValue::Number(2.0), @json.JsonValue::Number(3.0)],
        ),
      ],
    ),
  )
}
//endregion

//region nulls
test "parses nulls" {
  let json = test_parse!("null")
  @test.eq!(json, @json.JsonValue::Null)
}
//endregion

//region booleans
test "parses true" {
  let json = test_parse!("true")
  @test.eq!(json, @json.JsonValue::True)
}

test "parses false" {
  let json = test_parse!("false")
  @test.eq!(json, @json.JsonValue::False)
}
//endregion

//region numbers
test "parses leading zeroes" {
  let json = test_parse!("[0,0.,0e0]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(0.0),
        @json.JsonValue::Number(0.0),
        @json.JsonValue::Number(0.0),
      ],
    ),
  )
}

test "parses integers" {
  let json = test_parse!("[1,23,456,7890]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(1.0),
        @json.JsonValue::Number(23.0),
        @json.JsonValue::Number(456.0),
        @json.JsonValue::Number(7890.0),
      ],
    ),
  )
}

test "parses signed numbers" {
  let json = test_parse!("[-1,+2,-.1,-0]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(-1.0),
        @json.JsonValue::Number(2.0),
        @json.JsonValue::Number(-0.1),
        @json.JsonValue::Number(-0.0),
      ],
    ),
  )
}

test "parses leading decimal points" {
  let json = test_parse!("[.1,.23]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [@json.JsonValue::Number(0.1), @json.JsonValue::Number(0.23)],
    ),
  )
}

test "parses fractional numbers" {
  let json = test_parse!("[1.0,1.23]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [@json.JsonValue::Number(1.0), @json.JsonValue::Number(1.23)],
    ),
  )
}

test "parses exponents" {
  let json = test_parse!("[1e0,1e1,1e01,1.e0,1.1e0,1e-1,1e+1]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(1.0),
        @json.JsonValue::Number(10.0),
        @json.JsonValue::Number(10.0),
        @json.JsonValue::Number(1.0),
        @json.JsonValue::Number(1.1),
        @json.JsonValue::Number(0.1),
        @json.JsonValue::Number(10.0),
      ],
    ),
  )
}

test "parses hexadecimal numbers" {
  let json = test_parse!("[0x1,0x10,0xff,0xFF]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(1.0),
        @json.JsonValue::Number(16.0),
        @json.JsonValue::Number(255.0),
        @json.JsonValue::Number(255.0),
      ],
    ),
  )
}

test "parses signed and unsigned Infinity" {
  let json = test_parse!("[Infinity,-Infinity]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [
        @json.JsonValue::Number(@double.inf(1)),
        @json.JsonValue::Number(@double.inf(-1)),
      ],
    ),
  )
}

test "parses NaN" {
  let json = test_parse!("NaN")
  let ok = match json {
    @json.JsonValue::Number(n) => n.is_nan()
    _ => false
  }
  @test.is_true!(ok)
}

test "parses signed NaN" {
  let json = test_parse!("-NaN")
  let ok = match json {
    @json.JsonValue::Number(n) => n.is_nan()
    _ => false
  }
  @test.is_true!(ok)
}

test "parses 1" {
  let json = test_parse!("1")
  @test.eq!(json, @json.JsonValue::Number(1.0))
}

test "parses +1.23e100" {
  let json = test_parse!("+1.23e100")
  @test.eq!(json, @json.JsonValue::Number(1.23e100))
}

test "parses bare hexadecimal number" {
  let json = test_parse!("0x1")
  @test.eq!(json, @json.JsonValue::Number(1.0))
}

test "parses bare long hexadecimal number" {
  let json = test_parse!("-0x0123456789abcdefABCDEF")
  @test.eq!(json, @json.JsonValue::Number(-0x0123456789abcdefABCDEF.0))
}
//endregion

//region strings
test "parses double quoted strings" {
  let json = test_parse!("\"abc\"")
  @test.eq!(json, @json.JsonValue::String("abc"))
}

test "parses single quoted strings" {
  let json = test_parse!("'abc'")
  @test.eq!(json, @json.JsonValue::String("abc"))
}

test "parses quotes in strings" {
  let json = test_parse!("[\"\\\"\",\"'\"]")
  @test.eq!(
    json,
    @json.JsonValue::Array(
      [@json.JsonValue::String("\""), @json.JsonValue::String("'")],
    ),
  )
}

test "parses escaped characters" {
  let json = test_parse!("'\\b\\f\\n\\r\\t\\v\\0\\x0f\\u01fF\\a\\'\\\"'")
  @test.eq!(
    json,
    @json.JsonValue::String("\u0008\u000C\n\r\t\u000B\u0000\u000F\u01FFa'\""),
  )
}
// test "parses line and paragraph separators with a warning" {
//   let json = test_parse("'\u2028\u2029'")!
//   @test.eq(json, @json.JsonValue::String("\u2028\u2029"))!
// }
//endregion

//region comments
test "parses single-line comments" {
  let json = test_parse!("{//comment\n}")
  @test.eq!(json, @json.JsonValue::Object(Map::of([])))
}

test "parses single-line comments at end of input" {
  let json = test_parse!("{}//comment")
  @test.eq!(json, @json.JsonValue::Object(Map::of([])))
}

test "parses multi-line comments" {
  let json = test_parse!("{/*comment\n** */}")
  @test.eq!(json, @json.JsonValue::Object(Map::of([])))
}
//endregion

//region whitespace
test "parses whitespace" {
  let json = test_parse!("{\t\u000b\u000c \u00A0\uFEFF\n\r\u2028\u2029\u2003}")
  @test.eq!(json, @json.JsonValue::Object(Map::of([])))
}
//endregion

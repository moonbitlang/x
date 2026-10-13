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
fn expect_error(
  f : () -> Unit raise @json.ParseError,
) -> @json.ParseError raise Failure {
  try f() catch {
    error => error
  } noraise {
    _ => fail("expected parse error")
  }
}

///|
fn expect_parse_error(text : String) -> @json.ParseError raise Failure {
  expect_error(() => ignore(@json_stream.parse(text.iter())))
}

///|
test "rejects an empty stream" {
  @debug.assert_eq(expect_parse_error(""), @json.InvalidEof)
}

///|
test "rejects incomplete arrays and objects" {
  @debug.assert_eq(expect_parse_error("["), @json.InvalidEof)
  @debug.assert_eq(expect_parse_error("{\"a\":"), @json.InvalidEof)
  @debug.assert_eq(expect_parse_error("{\"a\":1"), @json.InvalidEof)
}

///|
test "rejects trailing input" {
  let error = expect_parse_error("{} []")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 3, })
      @debug.assert_eq(c, '[')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects invalid literals" {
  let error = expect_parse_error("tru")
  @debug.assert_eq(error, @json.InvalidEof)
  let error = expect_parse_error("nux")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 2, })
      @debug.assert_eq(c, 'x')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects invalid numbers" {
  let error = expect_parse_error("01")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 1, })
      @debug.assert_eq(c, '1')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("-")
  @debug.assert_eq(error, @json.InvalidEof)
  let error = expect_parse_error("1.")
  @debug.assert_eq(error, @json.InvalidEof)
  let error = expect_parse_error("1e+")
  @debug.assert_eq(error, @json.InvalidEof)
  let error = expect_parse_error("-01")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 2, })
      @debug.assert_eq(c, '1')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("1e")
  @debug.assert_eq(error, @json.InvalidEof)
  let error = expect_parse_error("1.e2")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 2, })
      @debug.assert_eq(c, 'e')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects invalid escapes" {
  let error = expect_parse_error("\"\\q\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 2, })
      @debug.assert_eq(c, 'q')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects malformed unicode escapes" {
  let error = expect_parse_error("\"\\u12g4\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 5, })
      @debug.assert_eq(c, 'g')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("\"\\ud83d\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 1, })
      @debug.assert_eq(c, '\\')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("\"\\ude00\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 1, })
      @debug.assert_eq(c, '\\')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("\"\\ud83dx\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 1, })
      @debug.assert_eq(c, '\\')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects raw control characters in strings" {
  let error = expect_parse_error("\"line\nfeed\"")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 5, })
      @debug.assert_eq(c, '\n')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects trailing separators" {
  let error = expect_parse_error("[1,]")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 3, })
      @debug.assert_eq(c, ']')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("{\"a\":1,}")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 7, })
      @debug.assert_eq(c, '}')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects nesting beyond the configured limit" {
  let error = expect_error(() => {
    ignore(@json_stream.parse("[[0]]".iter(), max_nesting_depth=1))
  })
  @debug.assert_eq(error, @json.DepthLimitExceeded)
}

///|
test "rejects both sides of mismatched containers" {
  let error = expect_parse_error("[}")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 1, })
      @debug.assert_eq(c, '}')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("{\"a\":1]")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 6, })
      @debug.assert_eq(c, ']')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "rejects missing separators and colons" {
  let error = expect_parse_error("[1 2]")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 3, })
      @debug.assert_eq(c, '2')
    }
    _ => fail("expected InvalidChar")
  }
  let error = expect_parse_error("{\"a\" 1}")
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 5, })
      @debug.assert_eq(c, '1')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "reports line and column across multiple lines" {
  let input =
    #|{
    #|  "a": 1,
    #|  "b": @
    #|}
  let error = expect_parse_error(input)
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 3, column: 7, })
      @debug.assert_eq(c, '@')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "only accepts RFC 8259 whitespace" {
  inspect(@json_stream.valid("{\u{00A0}}".iter()), content="false")
  inspect(@json_stream.valid("{\u{2028}}".iter()), content="false")
  inspect(@json_stream.valid("{\u{FEFF}}".iter()), content="false")
}

///|
test "reports the same selected errors as the core parser" {
  let cases : Array[(String, Int32, Int32, Char)] = [
    ("]", 1, 0, ']'),
    ("}", 1, 0, '}'),
    (",", 1, 0, ','),
    ("{a:1}", 1, 1, 'a'),
    ("{\"a\":1, b:2}", 1, 8, 'b'),
    ("{\"a\" b:2}", 1, 5, 'b'),
    ("{\"a\":1 b:2}", 1, 7, 'b'),
    ("[1, 2 a]", 1, 6, 'a'),
  ]
  for case in cases {
    let (input, line, column, expected_char) = case
    let error = expect_parse_error(input)
    match error {
      @json.InvalidChar(position, c) => {
        @debug.assert_eq(position, { line, column, })
        @debug.assert_eq(c, expected_char)
      }
      _ => fail("expected InvalidChar for " + input)
    }
  }
}

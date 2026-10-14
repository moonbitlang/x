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
fn event_text(event : @json_stream.Event) -> String {
  match event {
    @json_stream.StartObject => "{"
    @json_stream.EndObject => "}"
    @json_stream.StartArray => "["
    @json_stream.EndArray => "]"
    @json_stream.Key(key) => "$" + key
    @json_stream.StringValue(value) => "\"" + value + "\""
    @json_stream.NumberValue(value, _) => value.to_string()
    @json_stream.BooleanValue(value) => value.to_string()
    @json_stream.NullValue => "null"
  }
}

///|
fn step_text(step : @json_stream.ParseStep) -> String {
  match step {
    @json_stream.Event(event) => event_text(event)
    @json_stream.NeedMoreInput => "NeedMoreInput"
    @json_stream.Done => "Done"
  }
}

///|
fn next_text(parser : @json_stream.Parser) -> String raise @json.ParseError {
  step_text(parser.next())
}

///|
fn expect_next_error(parser : @json_stream.Parser) -> @json.ParseError {
  try {
    ignore(parser.next())
    abort("expected parser error")
  } catch {
    error => error
  }
}

///|
fn feed_and_collect(
  chunks : Array[String],
  eof~ : Bool = true,
) -> Array[String] raise @json.ParseError {
  let parser = @json_stream.Parser::new()
  for chunk in chunks {
    parser.feed(chunk)
  }
  if eof {
    parser.feed("", eof=true)
  }
  let events : Array[String] = []
  for ;; {
    match parser.next() {
      @json_stream.Event(event) => events.push(event_text(event))
      @json_stream.NeedMoreInput => return events
      @json_stream.Done => break
    }
  }
  events
}

///|
test "resumable parser emits object and array events" {
  let events = feed_and_collect([
    "{\"name\":\"mo", "on\",\"values\":[1,", "true,null]}",
  ])
  @debug.assert_eq(events, [
    "{", "$name", "\"moon\"", "$values", "[", "1", "true", "null", "]", "}",
  ])
}

///|
test "resumable parser distinguishes temporary exhaustion from final EOF" {
  let parser = @json_stream.Parser::new()
  parser.feed("{")
  @debug.assert_eq(next_text(parser), "{")
  parser.feed("\"a\"")
  @debug.assert_eq(next_text(parser), "$a")
  parser.feed(":")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("1")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("}")
  @debug.assert_eq(next_text(parser), "1")
  @debug.assert_eq(next_text(parser), "}")
  @debug.assert_eq(next_text(parser), "Done")
}

///|
test "resumable parser reports InvalidEof only after explicit EOF" {
  let parser = @json_stream.Parser::new()
  parser.feed("\"unfinished")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("", eof=true)
  let error = expect_next_error(parser)
  @debug.assert_eq(error, @json.InvalidEof)
}

///|
test "resumable parser handles token boundaries inside strings and numbers" {
  let parser = @json_stream.Parser::new()
  parser.feed("[")
  @debug.assert_eq(next_text(parser), "[")
  parser.feed("1")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("2,")
  @debug.assert_eq(next_text(parser), "12")
  parser.feed("\"\\u4e")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("2d\",")
  @debug.assert_eq(next_text(parser), "\"中\"")
  parser.feed("false]")
  @debug.assert_eq(next_text(parser), "false")
  @debug.assert_eq(next_text(parser), "]")
  @debug.assert_eq(next_text(parser), "Done")
}

///|
test "resumable parser accepts empty chunks between data" {
  let parser = @json_stream.Parser::new()
  parser.feed("")
  parser.feed("{}")
  parser.feed("")
  parser.feed("", eof=true)
  @debug.assert_eq(next_text(parser), "{")
  @debug.assert_eq(next_text(parser), "}")
  @debug.assert_eq(next_text(parser), "Done")
}

///|
test "resumable parser handles one-character chunks" {
  let parser = @json_stream.Parser::new()
  let text = "{\"a\":[1,true,null,\"中\"]}"
  for c in text {
    parser.feed(c.to_string())
  }
  parser.feed("", eof=true)
  let events : Array[String] = []
  for ;; {
    match parser.next() {
      @json_stream.Event(event) => events.push(event_text(event))
      @json_stream.NeedMoreInput => fail("unexpected NeedMoreInput")
      @json_stream.Done => break
    }
  }
  @debug.assert_eq(events, [
    "{", "$a", "[", "1", "true", "null", "\"中\"", "]", "}",
  ])
}

///|
test "resumable parser rejects trailing data after root" {
  let parser = @json_stream.Parser::new()
  parser.feed("{} []", eof=true)
  @debug.assert_eq(next_text(parser), "{")
  @debug.assert_eq(next_text(parser), "}")
  let error = expect_next_error(parser)
  match error {
    @json.InvalidChar(position, c) => {
      @debug.assert_eq(position, { line: 1, column: 3, })
      @debug.assert_eq(c, '[')
    }
    _ => fail("expected InvalidChar")
  }
}

///|
test "resumable parser reports incomplete number at final EOF" {
  let parser = @json_stream.Parser::new()
  parser.feed("1.", eof=true)
  let error = expect_next_error(parser)
  @debug.assert_eq(error, @json.InvalidEof)
}

///|
test "resumable parser can be polled after every chunk" {
  let parser = @json_stream.Parser::new()
  parser.feed("t")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("r")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("u")
  @debug.assert_eq(next_text(parser), "NeedMoreInput")
  parser.feed("e")
  @debug.assert_eq(next_text(parser), "true")
  parser.feed("")
  @debug.assert_eq(next_text(parser), "Done")
}

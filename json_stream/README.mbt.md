# moonbitlang/x/json_stream

`moonbitlang/x/json_stream` provides a resumable JSON parser for data that
arrives in chunks.

The parser retains its grammar state across chunk boundaries. `NeedMoreInput`
means the current chunk is exhausted, but the document may continue.
`feed(..., eof=true)` declares final end of input, so an unfinished string,
number, container, or literal can be reported as a real parse error.

The parser emits structural and value events as they become available. It does
not require callers to build the complete document as a `String` first.

## Streaming Example

```mbt check
///|
test {
  let parser = @json_stream.Parser::new()
  parser.feed("{\"items\":[1,")
  let first = parser.next()
  inspect(first is @json_stream.Event(@json_stream.StartObject), content="true")
  parser.feed("2")
  inspect(
    parser.next() is @json_stream.Event(@json_stream.Key("items")),
    content="true",
  )
}
```

## Event API

```moonbit nocheck
pub fn Parser::new(
  max_nesting_depth? : Int = 1024,
) -> Parser

pub fn Parser::feed(
  Self,
  chunk : StringView,
  eof? : Bool = false,
) -> Unit

pub fn Parser::next(
  Self,
) -> ParseStep raise @json.ParseError
```

`ParseStep` has three cases:

- `Event(event)` for the next structural token or value.
- `NeedMoreInput` when the current chunk is exhausted before the current token
  is complete.
- `Done` after the root value is complete.

Events include `StartObject`, `EndObject`, `StartArray`, `EndArray`, `Key`,
`StringValue`, `NumberValue`, `BooleanValue`, and `NullValue`.

## Tree Convenience API

The original convenience API remains available for callers that already have
the complete document:

```moonbit nocheck
pub fn parse(
  input : Iter[Char],
  max_nesting_depth? : Int = 1024,
) -> @json.Json raise @json.ParseError

pub fn valid(input : Iter[Char]) -> Bool
```

`parse` consumes exactly one JSON document, allows leading and trailing JSON
whitespace, and rejects any additional characters.

## Chunk Boundaries

Each `StringView` chunk must end on a Unicode scalar boundary. A chunk may end
in the middle of a JSON token, escape sequence, number, object, or array.

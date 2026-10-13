# moonbitlang/x/json_stream

`moonbitlang/x/json_stream` parses one JSON document directly from an
`Iter[Char]`.

The parser keeps only one character of lookahead and buffers individual string
and number tokens. It does not first collect the complete input into a
`String`, which is useful when characters arrive from a UTF-8 decoder, file
reader, or HTTP response body.

The returned value is the standard `moonbitlang/core/json.Json` type and errors
use `moonbitlang/core/json.ParseError`.

## Example

```mbt check
///|
test {
  let json = @json_stream.parse("{\"items\":[1,2,3],\"ok\":true}".iter())
  inspect(json.stringify(), content="{\"items\":[1,2,3],\"ok\":true}")
}
```

## API

```moonbit nocheck
pub fn parse(
  input : Iter[Char],
  max_nesting_depth? : Int = 1024,
) -> @json.Json raise @json.ParseError

pub fn valid(input : Iter[Char]) -> Bool
```

`parse` consumes exactly one JSON document, allows leading and trailing JSON
whitespace, and rejects any additional characters.

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
fn lex_value(
  ctx : ParseContext,
  allow_rbracket? : Bool = false,
) -> Token raise ParseError {
  for ;; {
    let view = ctx.input[ctx.offset:]
    lexscan view with longest {
      (
        re"^[\t\u000B\u000C \n\r\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]",
        after=rest,
      ) => {
        ctx.offset = rest.start_offset()
        continue
      }
      (re"^//[^\n\r\u2028\u2029]*", after=rest) => {
        ctx.offset = rest.start_offset()
        continue
      }
      (re"^/[*]([*][^/]?|[^*])*[*]/", after=rest) => {
        ctx.offset = rest.start_offset()
        continue
      }
      re"^/[*]([*][^/]?|[^*])*$" => parse_error(InvalidEof)
      (re"^[{]", after=rest) => {
        ctx.offset = rest.start_offset()
        return LBrace
      }
      (re"^\[", after=rest) => {
        ctx.offset = rest.start_offset()
        return LBracket
      }
      (re"^\]", after=rest) =>
        if allow_rbracket {
          ctx.offset = rest.start_offset()
          return RBracket
        } else {
          invalid_char(ctx)
        }
      (re"^null", after=rest) => {
        ctx.offset = rest.start_offset()
        return Null
      }
      (re"^true", after=rest) => {
        ctx.offset = rest.start_offset()
        return True
      }
      (re"^false", after=rest) => {
        ctx.offset = rest.start_offset()
        return False
      }
      (re"^\+?0[xX]", after=rest) => {
        ctx.offset = rest.start_offset()
        let n = lex_hexadecimal(ctx, neg=false)
        return Number(n)
      }
      (re"^-0[xX]", after=rest) => {
        ctx.offset = rest.start_offset()
        let n = lex_hexadecimal(ctx, neg=true)
        return Number(n)
      }
      (
        re"^[+\-]?((0|[1-9][0-9]*)(\.[0-9]*)?|\.[0-9]+)([eE][+\-]?[0-9]+)?" as lit,
        after=rest,
      ) => {
        ctx.offset = rest.start_offset()
        let n = lex_number_end(
          ctx,
          lit.start_offset(),
          lit.start_offset() + lit.length(),
        )
        return Number(n)
      }
      (re"^\+?Infinity", after=rest) => {
        ctx.offset = rest.start_offset()
        return Number(@double.infinity)
      }
      (re"^-Infinity", after=rest) => {
        ctx.offset = rest.start_offset()
        return Number(@double.neg_infinity)
      }
      (re"^[+\-]?NaN", after=rest) => {
        ctx.offset = rest.start_offset()
        return Number(@double.not_a_number)
      }
      (re"^\"", after=rest) => {
        ctx.offset = rest.start_offset()
        let s = lex_string(ctx, '"')
        return String(s)
      }
      (re"^'", after=rest) => {
        ctx.offset = rest.start_offset()
        let s = lex_string(ctx, '\'')
        return String(s)
      }
      (re"^.", after=rest) => {
        ctx.offset = rest.start_offset()
        no_valid_token(ctx)
      }
      re"^$" => parse_error(InvalidEof)
      _ => panic()
    }
  }
}

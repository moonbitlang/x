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
test "encoding uses the selected ASCII characters" {
  inspect(
    @percent.encode("hello world /?+%~"),
    content="hello%20world%20%2F%3F%2B%25%7E",
  )
  let fragment = @percent.controls + " \"<>`"
  inspect(
    @percent.encode("hello world/?+%", escape_chars=fragment),
    content="hello%20world/?+%",
  )
  inspect(
    @percent.encode(
      "\u0000\u001F \u007F\u0080ÿ",
      escape_chars=@percent.controls,
    ),
    content="%00%1F %7F%C2%80%C3%BF",
  )
}

///|
test "escape characters cover word boundaries and ignore non-ASCII characters" {
  let boundaries = "\u0000?@\u007F\u0080ÿ"
  let chars = "\u0000?@\u007F\u0080ÿ工具🙂??"
  inspect(
    @percent.encode(boundaries, escape_chars=chars),
    content="%00%3F%40%7F%C2%80%C3%BF",
  )
  assert_eq(
    @percent.encode(boundaries, escape_chars=""),
    "\u0000?@\u007F%C2%80%C3%BF",
  )
  inspect(
    @percent.encode("AZaz09-._~ /", escape_chars=" /"),
    content="AZaz09-._~%20%2F",
  )
}

///|
test "decoding preserves malformed escapes and decodes only once" {
  assert_eq(@percent.decode("a%2fb%2Fc%20+%2B%25"), b"a/b/c ++%")
  assert_eq(@percent.decode("%2541%+1%-1%GG%2%"), b"%41%+1%-1%GG%2%")
  assert_eq(@percent.decode("%%41%4%42%"), b"%A%4B%")
  assert_eq(@percent.decode(""), b"")
  assert_eq(@percent.encode(""), "")
}

///|
test "UTF-8 text and escaped binary data are preserved" {
  let text = "工具🙂"
  let encoded = @percent.encode(text)
  inspect(encoded, content="%E5%B7%A5%E5%85%B7%F0%9F%99%82")
  assert_eq(@utf8.decode(@percent.decode(encoded)), text)
  assert_eq(@percent.decode("工具%F0%9F%99%82"), @utf8.encode(text))
  let raw = "%FF%C0%AF%ED%A0%80%00"
  assert_eq(@percent.decode(raw), b"\xFF\xC0\xAF\xED\xA0\x80\x00")
}

///|
test "decoding covers all bytes and encoding honors every ASCII member" {
  let mut value = 0
  for hi in "0123456789ABCDEF" {
    for lo in "0123456789abcdef" {
      assert_eq(
        @percent.decode("%\{hi}\{lo}"),
        Bytes::from_array([value.to_byte()]),
      )
      value += 1
    }
  }
  for value in 0..<128 {
    let input = value.unsafe_to_char().to_string()
    let encoded = @percent.encode(input, escape_chars=input)
    assert_eq(encoded.length(), 3)
    assert_eq(@percent.decode(encoded), @utf8.encode(input))
    assert_eq(@percent.encode(input, escape_chars="").length(), 1)
    let expected_length = if value is ('A'..='Z' | 'a'..='z' | '0'..='9') {
      1
    } else {
      3
    }
    assert_eq(@percent.encode(input).length(), expected_length)
  }
}

///|
test "views do not decode or encode outside their bounds" {
  let input = "xx%41%42yy"
  assert_eq(@percent.decode(input[2:8]), b"AB")
  assert_eq(@percent.decode(input[2:4]), b"%4")
  assert_eq(@percent.encode(input[2:8]), "%2541%2542")
  let unicode = "x工具🙂y"
  assert_eq(@percent.decode(unicode[1:5]), @utf8.encode("工具🙂"))
  assert_eq(@percent.encode(unicode[1:5]), "%E5%B7%A5%E5%85%B7%F0%9F%99%82")
}

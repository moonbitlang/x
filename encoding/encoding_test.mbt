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
test "encoding String to UTF8" {
  let src = "你好👀"
  let bytes = @encoding.encode(UTF8, src)
  inspect(
    bytes,
    content=(
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ),
  )
}

///|
test "debug encoding" {
  let encodings : Array[@encoding.Encoding] = [UTF8, UTF16, UTF16LE, UTF16BE]
  debug_inspect(encodings, content="[UTF8, UTF16, UTF16LE, UTF16BE]")
}

///|
test "write_string_utf8" {
  let src = "你好👀"
  let buf = Buffer(size_hint=10)
  buf.write_string_utf8(src)
  inspect(
    buf.to_bytes(),
    content=(
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ),
  )
}

///|
test "encoding String to UTF16 (alias of UTF16LE)" {
  let src = "LISP programmers know the value of everything"
  let bytes = @encoding.encode(UTF16, src)
  inspect(
    bytes,
    content=(
      #|b"L\x00I\x00S\x00P\x00 \x00p\x00r\x00o\x00g\x00r\x00a\x00m\x00m\x00e\x00r\x00s\x00 \x00k\x00n\x00o\x00w\x00 \x00t\x00h\x00e\x00 \x00v\x00a\x00l\x00u\x00e\x00 \x00o\x00f\x00 \x00e\x00v\x00e\x00r\x00y\x00t\x00h\x00i\x00n\x00g\x00"
    ),
  )
}

///|
test "write_string_utf16le" {
  let src = "LISP programmers know the value of everything"
  let buf = Buffer(size_hint=10)
  buf.write_string_utf16le(src)
  inspect(
    buf.to_bytes(),
    content=(
      #|b"L\x00I\x00S\x00P\x00 \x00p\x00r\x00o\x00g\x00r\x00a\x00m\x00m\x00e\x00r\x00s\x00 \x00k\x00n\x00o\x00w\x00 \x00t\x00h\x00e\x00 \x00v\x00a\x00l\x00u\x00e\x00 \x00o\x00f\x00 \x00e\x00v\x00e\x00r\x00y\x00t\x00h\x00i\x00n\x00g\x00"
    ),
  )
}

///|
test "encoding String to UTF16LE" {
  let src = "and the cost of nothing"
  let bytes = @encoding.encode(UTF16LE, src)
  inspect(
    bytes,
    content=(
      #|b"a\x00n\x00d\x00 \x00t\x00h\x00e\x00 \x00c\x00o\x00s\x00t\x00 \x00o\x00f\x00 \x00n\x00o\x00t\x00h\x00i\x00n\x00g\x00"
    ),
  )
}

///|
test "encoding String to UTF16BE" {
  let src = "λf.(λx.f(x x))(λx.f(x x))"
  let bytes = @encoding.encode(UTF16BE, src)
  inspect(
    bytes,
    content=(
      #|b"\x03\xbb\x00f\x00.\x00(\x03\xbb\x00x\x00.\x00f\x00(\x00x\x00 \x00x\x00)\x00)\x00(\x03\xbb\x00x\x00.\x00f\x00(\x00x\x00 \x00x\x00)\x00)"
    ),
  )
}

///|
test "write_string_utf16be" {
  let src = "λf.(λx.f(x x))(λx.f(x x))"
  let buf = Buffer(size_hint=10)
  buf.write_string_utf16be(src)
  inspect(
    buf.to_bytes(),
    content=(
      #|b"\x03\xbb\x00f\x00.\x00(\x03\xbb\x00x\x00.\x00f\x00(\x00x\x00 \x00x\x00)\x00)\x00(\x03\xbb\x00x\x00.\x00f\x00(\x00x\x00 \x00x\x00)\x00)"
    ),
  )
}

///|
test "to_utf8_bytes" {
  inspect(
    @encoding.to_utf8_bytes('A'),
    content=(
      #|b"A"
    ),
  )
  inspect(
    @encoding.to_utf8_bytes('α'),
    content=(
      #|b"\xce\xb1"
    ),
  )
  inspect(
    @encoding.to_utf8_bytes('啊'),
    content=(
      #|b"\xe5\x95\x8a"
    ),
  )
  inspect(
    @encoding.to_utf8_bytes('😦'),
    content=(
      #|b"\xf0\x9f\x98\xa6"
    ),
  )
}

///|
test "to_utf16le_bytes" {
  inspect(
    @encoding.to_utf16le_bytes('A'),
    content=(
      #|b"A\x00"
    ),
  )
  inspect(
    @encoding.to_utf16le_bytes('α'),
    content=(
      #|b"\xb1\x03"
    ),
  )
  inspect(
    @encoding.to_utf16le_bytes('啊'),
    content=(
      #|b"JU"
    ),
  )
  inspect(
    @encoding.to_utf16le_bytes('😦'),
    content=(
      #|b"=\xd8&\xde"
    ),
  )
}

///|
test "to_utf16be_bytes" {
  inspect(
    @encoding.to_utf16be_bytes('A'),
    content=(
      #|b"\x00A"
    ),
  )
  inspect(
    @encoding.to_utf16be_bytes('α'),
    content=(
      #|b"\x03\xb1"
    ),
  )
  inspect(
    @encoding.to_utf16be_bytes('啊'),
    content=(
      #|b"UJ"
    ),
  )
  inspect(
    @encoding.to_utf16be_bytes('😦'),
    content=(
      #|b"\xd8=\xde&"
    ),
  )
}

///|
test "write_char_utf8" {
  let buf = Buffer(size_hint=10)
  buf.write_char_utf8('A')
  buf.write_char_utf8('α')
  buf.write_char_utf8('啊')
  buf.write_char_utf8('😦')
  inspect(
    buf.to_bytes(),
    content=(
      #|b"A\xce\xb1\xe5\x95\x8a\xf0\x9f\x98\xa6"
    ),
  )
}

///|
test "write_char_utf16le" {
  let buf = Buffer(size_hint=10)
  buf.write_char_utf16le('A')
  buf.write_char_utf16le('α')
  buf.write_char_utf16le('啊')
  buf.write_char_utf16le('😦')
  inspect(
    buf.to_bytes(),
    content=(
      #|b"A\x00\xb1\x03JU=\xd8&\xde"
    ),
  )
}

///|
test "write_char_utf16be" {
  let buf = Buffer(size_hint=10)
  buf.write_char_utf16be('A')
  buf.write_char_utf16be('α')
  buf.write_char_utf16be('啊')
  buf.write_char_utf16be('😦')
  inspect(
    buf.to_bytes(),
    content=(
      #|b"\x00A\x03\xb1UJ\xd8=\xde&"
    ),
  )
}

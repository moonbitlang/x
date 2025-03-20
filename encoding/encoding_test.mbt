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

///|
test "encoding String to UTF8" {
  let src = "你好👀"
  let bytes = @encoding.encode(UTF8, src)
  inspect!(
    bytes,
    content=
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ,
  )
}

///|
test "encode_to/UTF8" {
  let src = "你好👀"
  let buf = @buffer.new(size_hint=10)
  @encoding.encode_to(src, buf, encoding=UTF8)
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ,
  )
}

///|
test "encoding String to UTF16 (alias of UTF16LE)" {
  let src = "LISP programmers know the value of everything"
  let bytes = @encoding.encode(UTF16, src)
  inspect!(
    bytes,
    content=
      #|b"\x4c\x00\x49\x00\x53\x00\x50\x00\x20\x00\x70\x00\x72\x00\x6f\x00\x67\x00\x72\x00\x61\x00\x6d\x00\x6d\x00\x65\x00\x72\x00\x73\x00\x20\x00\x6b\x00\x6e\x00\x6f\x00\x77\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x76\x00\x61\x00\x6c\x00\x75\x00\x65\x00\x20\x00\x6f\x00\x66\x00\x20\x00\x65\x00\x76\x00\x65\x00\x72\x00\x79\x00\x74\x00\x68\x00\x69\x00\x6e\x00\x67\x00"
    ,
  )
}

///|
test "encode_to/UTF16" {
  let src = "LISP programmers know the value of everything"
  let buf = @buffer.new(size_hint=10)
  @encoding.encode_to(src, buf, encoding=UTF16)
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x4c\x00\x49\x00\x53\x00\x50\x00\x20\x00\x70\x00\x72\x00\x6f\x00\x67\x00\x72\x00\x61\x00\x6d\x00\x6d\x00\x65\x00\x72\x00\x73\x00\x20\x00\x6b\x00\x6e\x00\x6f\x00\x77\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x76\x00\x61\x00\x6c\x00\x75\x00\x65\x00\x20\x00\x6f\x00\x66\x00\x20\x00\x65\x00\x76\x00\x65\x00\x72\x00\x79\x00\x74\x00\x68\x00\x69\x00\x6e\x00\x67\x00"
    ,
  )
}

///|
test "encoding String to UTF16LE" {
  let src = "and the cost of nothing"
  let bytes = @encoding.encode(UTF16LE, src)
  inspect!(
    bytes,
    content=
      #|b"\x61\x00\x6e\x00\x64\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x63\x00\x6f\x00\x73\x00\x74\x00\x20\x00\x6f\x00\x66\x00\x20\x00\x6e\x00\x6f\x00\x74\x00\x68\x00\x69\x00\x6e\x00\x67\x00"
    ,
  )
}

///|
test "encode_to/UTF16LE" {
  let src = "and the cost of nothing"
  let buf = @buffer.new(size_hint=10)
  @encoding.encode_to(src, buf, encoding=UTF16LE)
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x61\x00\x6e\x00\x64\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x63\x00\x6f\x00\x73\x00\x74\x00\x20\x00\x6f\x00\x66\x00\x20\x00\x6e\x00\x6f\x00\x74\x00\x68\x00\x69\x00\x6e\x00\x67\x00"
    ,
  )
}

///|
test "encoding String to UTF16BE" {
  let src = "λf.(λx.f(x x))(λx.f(x x))"
  let bytes = @encoding.encode(UTF16BE, src)
  inspect!(
    bytes,
    content=
      #|b"\x03\xbb\x00\x66\x00\x2e\x00\x28\x03\xbb\x00\x78\x00\x2e\x00\x66\x00\x28\x00\x78\x00\x20\x00\x78\x00\x29\x00\x29\x00\x28\x03\xbb\x00\x78\x00\x2e\x00\x66\x00\x28\x00\x78\x00\x20\x00\x78\x00\x29\x00\x29"
    ,
  )
}

///|
test "encode_to/UTF16BE" {
  let src = "λf.(λx.f(x x))(λx.f(x x))"
  let buf = @buffer.new(size_hint=10)
  @encoding.encode_to(src, buf, encoding=UTF16BE)
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x03\xbb\x00\x66\x00\x2e\x00\x28\x03\xbb\x00\x78\x00\x2e\x00\x66\x00\x28\x00\x78\x00\x20\x00\x78\x00\x29\x00\x29\x00\x28\x03\xbb\x00\x78\x00\x2e\x00\x66\x00\x28\x00\x78\x00\x20\x00\x78\x00\x29\x00\x29"
    ,
  )
}

///|
test "to_utf8_bytes" {
  inspect!(
    @encoding.to_utf8_bytes('A'),
    content=
      #|b"\x41"
    ,
  )
  inspect!(
    @encoding.to_utf8_bytes('α'),
    content=
      #|b"\xce\xb1"
    ,
  )
  inspect!(
    @encoding.to_utf8_bytes('啊'),
    content=
      #|b"\xe5\x95\x8a"
    ,
  )
  inspect!(
    @encoding.to_utf8_bytes('😦'),
    content=
      #|b"\xf0\x9f\x98\xa6"
    ,
  )
}

///|
test "to_utf16_bytes (alias for to_utf16le_bytes)" {
  inspect!(
    @encoding.to_utf16_bytes('A'),
    content=
      #|b"\x41\x00"
    ,
  )
  inspect!(
    @encoding.to_utf16_bytes('α'),
    content=
      #|b"\xb1\x03"
    ,
  )
  inspect!(
    @encoding.to_utf16_bytes('啊'),
    content=
      #|b"\x4a\x55"
    ,
  )
  inspect!(
    @encoding.to_utf16_bytes('😦'),
    content=
      #|b"\x3d\xd8\x26\xde"
    ,
  )
}

///|
test "to_utf16le_bytes" {
  inspect!(
    @encoding.to_utf16le_bytes('A'),
    content=
      #|b"\x41\x00"
    ,
  )
  inspect!(
    @encoding.to_utf16le_bytes('α'),
    content=
      #|b"\xb1\x03"
    ,
  )
  inspect!(
    @encoding.to_utf16le_bytes('啊'),
    content=
      #|b"\x4a\x55"
    ,
  )
  inspect!(
    @encoding.to_utf16le_bytes('😦'),
    content=
      #|b"\x3d\xd8\x26\xde"
    ,
  )
}

///|
test "to_utf16be_bytes" {
  inspect!(
    @encoding.to_utf16be_bytes('A'),
    content=
      #|b"\x00\x41"
    ,
  )
  inspect!(
    @encoding.to_utf16be_bytes('α'),
    content=
      #|b"\x03\xb1"
    ,
  )
  inspect!(
    @encoding.to_utf16be_bytes('啊'),
    content=
      #|b"\x55\x4a"
    ,
  )
  inspect!(
    @encoding.to_utf16be_bytes('😦'),
    content=
      #|b"\xd8\x3d\xde\x26"
    ,
  )
}

///|
test "write_utf8_char" {
  let buf = @buffer.new(size_hint=10)
  @encoding.write_utf8_char(buf, 'A')
  @encoding.write_utf8_char(buf, 'α')
  @encoding.write_utf8_char(buf, '啊')
  @encoding.write_utf8_char(buf, '😦')
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x41\xce\xb1\xe5\x95\x8a\xf0\x9f\x98\xa6"
    ,
  )
}

///|
test "write_utf16_char (alias for write_utf16le_char)" {
  let buf = @buffer.new(size_hint=10)
  @encoding.write_utf16_char(buf, 'A')
  @encoding.write_utf16_char(buf, 'α')
  @encoding.write_utf16_char(buf, '啊')
  @encoding.write_utf16_char(buf, '😦')
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x41\x00\xb1\x03\x4a\x55\x3d\xd8\x26\xde"
    ,
  )
}

///|
test "write_utf16le_char" {
  let buf = @buffer.new(size_hint=10)
  @encoding.write_utf16le_char(buf, 'A')
  @encoding.write_utf16le_char(buf, 'α')
  @encoding.write_utf16le_char(buf, '啊')
  @encoding.write_utf16le_char(buf, '😦')
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x41\x00\xb1\x03\x4a\x55\x3d\xd8\x26\xde"
    ,
  )
}

///|
test "write_utf16be_char" {
  let buf = @buffer.new(size_hint=10)
  @encoding.write_utf16be_char(buf, 'A')
  @encoding.write_utf16be_char(buf, 'α')
  @encoding.write_utf16be_char(buf, '啊')
  @encoding.write_utf16be_char(buf, '😦')
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x00\x41\x03\xb1\x55\x4a\xd8\x3d\xde\x26"
    ,
  )
}

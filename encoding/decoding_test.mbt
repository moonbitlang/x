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

// lossy

test "lossy decoding String (UTF16LE encoded) to String (buffer.write_bytes)" {
  let src = "你好👀"
  let buf = @buffer.new(size_hint=src.to_bytes().length())
  buf.write_bytes(src.to_bytes())
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x60\x4f\x7d\x59\x3d\xd8\x40\xdc"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16LE, buf.to_bytes())
  inspect!(chars, content=src)
}

test "lossy decoding String (UTF16LE encoded) to String (buffer.write_char)" {
  let src = "👋再见"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    buf.write_char(s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x3d\xd8\x4b\xdc\x8d\x51\xc1\x89"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16LE, buf.to_bytes())
  inspect!(chars, content=src)
}

test "lossy decoding UTF16LE encoded data to String" {
  let buf = @buffer.new(size_hint=10)
  buf.write_bytes(b"\x60\x4f")
  buf.write_bytes(b"\x7d\x59")
  buf.write_bytes(b"\x3d\xd8\x40\xdc")
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x60\x4f\x7d\x59\x3d\xd8\x40\xdc"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16LE, buf.to_bytes())
  inspect!(chars, content="你好👀")
}

test "lossy decoding UTF16 (alias for UTF16LE) encoded data to String" {
  let buf = @buffer.new(size_hint=20)
  buf.write_bytes(b"\x65\x18")
  buf.write_bytes(b"\x20\x18")
  buf.write_bytes(b"\x73\x18")
  buf.write_bytes(b"\x64\x18")
  buf.write_bytes(b"\x73\x18")
  buf.write_bytes(b"\x36\x18")
  buf.write_bytes(b"\x20\x18")
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x65\x18\x20\x18\x73\x18\x64\x18\x73\x18\x36\x18\x20\x18"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16, buf.to_bytes())
  inspect!(chars, content="ᡥᠠᡳᡤᡳᠶᠠ")
}

test "lossy decoding UTF16BE encoded data to String" {
  let buf = @buffer.new(size_hint=10)
  buf.write_bytes(b"\xd8\x3d\xdc\x08")
  buf.write_bytes(b"\xd8\x3d\xdc\x31")
  buf.write_bytes(b"\xd8\x3d\xdc\x07")
  buf.write_bytes(b"\xd8\x3d\xdc\x30")
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xd8\x3d\xdc\x08\xd8\x3d\xdc\x31\xd8\x3d\xdc\x07\xd8\x3d\xdc\x30"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16BE, buf.to_bytes())
  inspect!(chars, content="🐈🐱🐇🐰")
}

test "lossy decoding UTF8 encoded data to String" {
  let buf = @buffer.new(size_hint=10)
  buf.write_bytes(b"\xe4\xbd\xa0")
  buf.write_bytes(b"\xe5\xa5\xbd")
  buf.write_bytes(b"\xf0\x9f\x91\x80")
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ,
  )
  let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
  inspect!(chars, content="你好👀")
}

test "lossy decoding UTF8 encoded bytes to String" {
  let src = "👋再见"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xf0\x9f\x91\x8b\xe5\x86\x8d\xe8\xa7\x81"
    ,
  )
  let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
  inspect!(chars, content=src)
}

test "lossy decoding UTF8 encoded data" {
  let src = "👋再见"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xf0\x9f\x91\x8b\xe5\x86\x8d\xe8\xa7\x81"
    ,
  )
  let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
  inspect!(chars.iter().collect(), content="['👋', '再', '见']")
}

test "lossy decoding UTF16LE encoded data with UTF8" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16le_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xd1\x8d\x65\x6b\x3c\xd8\xc3\xdf\x38\x6e\xf3\x6c\x3c\xd8\xca\xdf"
    ,
  )
  let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content="['э', 'e', 'k', '<', '�', '�', 'n', '�', '�']",
  )
}

test "lossy decoding UTF8 encoded data with UTF16LE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe8\xb7\x91\xe6\xad\xa5\xf0\x9f\x8f\x83\xe6\xb8\xb8\xe6\xb3\xb3\xf0\x9f\x8f\x8a"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16LE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content="['럨', '', 'ꖭ', '鿰', '莏', '룦', '', '뎳', '鿰', '誏']",
  )
}

test "lossy decoding UTF16BE encoded data with UTF8" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16be_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x8d\xd1\x6b\x65\xd8\x3c\xdf\xc3\x6e\x38\x6c\xf3\xd8\x3c\xdf\xca"
    ,
  )
  let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content=
      #|['�', '�', 'e', '�', '�', 'n', '8', 'l', '�', '�']
    ,
  )
}

test "lossy decoding UTF8 encoded data with UTF16BE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe8\xb7\x91\xe6\xad\xa5\xf0\x9f\x8f\x83\xe6\xb8\xb8\xe6\xb3\xb3\xf0\x9f\x8f\x8a"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16BE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content="['', '釦', '궥', '', '较', '', '룦', '뎳', '', '辊']",
  )
}

test "lossy decoding UTF16LE encoded data with UTF16BE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16le_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xd1\x8d\x65\x6b\x3c\xd8\xc3\xdf\x38\x6e\xf3\x6c\x3c\xd8\xca\xdf"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16BE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content="['톍', '敫', '㳘', '쏟', '㡮', '', '㳘', '쫟']",
  )
}

test "lossy decoding UTF16BE encoded data with UTF16LE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16be_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x8d\xd1\x6b\x65\xd8\x3c\xdf\xc3\x6e\x38\x6c\xf3\xd8\x3c\xdf\xca"
    ,
  )
  let chars = @encoding.decode_lossy(UTF16LE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content="['톍', '敫', '㳘', '쏟', '㡮', '', '㳘', '쫟']",
  )
}

// strictly

test "strictly decoding UTF16LE encoded data with UTF8" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16le_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xd1\x8d\x65\x6b\x3c\xd8\xc3\xdf\x38\x6e\xf3\x6c\x3c\xd8\xca\xdf"
    ,
  )
  let chars = @encoding.decode_strict(UTF8, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content=
      #|[Ok('э'), Ok('e'), Ok('k'), Ok('<'), Err(b"\xd8\xc3"), Err(b"\xdf\x38"), Ok('n'), Err(b"\xf3\x6c\x3c\xd8"), Err(b"\xca\xdf")]
    ,
  )
}

test "strictly decoding UTF8 encoded data with UTF16LE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe8\xb7\x91\xe6\xad\xa5\xf0\x9f\x8f\x83\xe6\xb8\xb8\xe6\xb3\xb3\xf0\x9f\x8f\x8a"
    ,
  )
  let chars = @encoding.decode_strict(UTF16LE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content=
      #|[Ok('럨'), Ok(''), Ok('ꖭ'), Ok('鿰'), Ok('莏'), Ok('룦'), Ok(''), Ok('뎳'), Ok('鿰'), Ok('誏')]
    ,
  )
}

test "strictly decoding UTF8 encoded data with UTF16BE" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf8_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe8\xb7\x91\xe6\xad\xa5\xf0\x9f\x8f\x83\xe6\xb8\xb8\xe6\xb3\xb3\xf0\x9f\x8f\x8a"
    ,
  )
  let chars = @encoding.decode_strict(UTF16BE, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content=
      #|[Ok(''), Ok('釦'), Ok('궥'), Ok(''), Ok('较'), Ok(''), Ok('룦'), Ok('뎳'), Ok(''), Ok('辊')]
    ,
  )
}

test "strictly decoding UTF16BE encoded data with UTF8" {
  let src = "跑步🏃游泳🏊"
  let buf = @buffer.new(size_hint=10)
  for s in src {
    @encoding.write_utf16be_char(buf, s)
  }
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x8d\xd1\x6b\x65\xd8\x3c\xdf\xc3\x6e\x38\x6c\xf3\xd8\x3c\xdf\xca"
    ,
  )
  let chars = @encoding.decode_strict(UTF8, buf.to_bytes())
  inspect!(
    chars.iter().collect(),
    content=
      #|[Err(b"\x8d"), Err(b"\xd1\x6b"), Ok('e'), Err(b"\xd8\x3c"), Err(b"\xdf\xc3"), Ok('n'), Ok('8'), Ok('l'), Err(b"\xf3\xd8\x3c\xdf"), Err(b"\x00")]
    ,
  )
}

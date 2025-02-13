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

// Streaming

///|
test "streaming decoding UTF8 rabbit" {
  let inputs = [b"abc", b"\xf0\x9f", b"\x90\xb0"] // utf8(🐰) == F0 9F 90 B0
  let decoder = @encoding.decoder(UTF8)
  inspect!(decoder.decode!(inputs[0]), content="abc")
  inspect!(decoder.decode!(inputs[1]), content="")
  inspect!(decoder.decode!(inputs[2]), content="🐰")
}

///|
test "streaming decoding UTF16LE ASCII" {
  let ascii = "How do we grasp all the apples at once?"
  let from_array = Bytes::from_array
  let decoder = @encoding.decoder(UTF16LE)

  // NOTE: `to_bytes` means `to_utf16le_bytes` to MoonBit String
  let chunks = ascii.to_bytes().to_array().chunks(17)
  assert_eq!(chunks.length(), 5)

  // chunk by chunk
  assert_eq!(
    from_array(chunks[0]),
    b"\x48\x00\x6f\x00\x77\x00\x20\x00\x64\x00\x6f\x00\x20\x00\x77\x00\x65",
  )
  inspect!(decoder.decode!(from_array(chunks[0])), content="How do w")
  assert_eq!(
    from_array(chunks[1]),
    b"\x00\x20\x00\x67\x00\x72\x00\x61\x00\x73\x00\x70\x00\x20\x00\x61\x00",
  )
  inspect!(decoder.decode!(from_array(chunks[1])), content="e grasp a")
  assert_eq!(
    from_array(chunks[2]),
    b"\x6c\x00\x6c\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x61\x00\x70",
  )
  inspect!(decoder.decode!(from_array(chunks[2])), content="ll the a")
  assert_eq!(
    from_array(chunks[3]),
    b"\x00\x70\x00\x6c\x00\x65\x00\x73\x00\x20\x00\x61\x00\x74\x00\x20\x00",
  )
  inspect!(decoder.decode!(from_array(chunks[3])), content="pples at ")
  assert_eq!(from_array(chunks[4]), b"\x6f\x00\x6e\x00\x63\x00\x65\x00\x3f\x00")
  inspect!(decoder.decode!(from_array(chunks[4])), content="once?")

  // check accumulator
  let decoder = @encoding.decoder(UTF16LE)
  let mut acc = ""
  for chunk in ascii.to_bytes().to_array().chunks(7) {
    acc += decoder.decode!(from_array(chunk))
  }
  inspect!(acc, content=ascii)
}

// In one go

///|
test "decoding String (UTF16LE encoded) to String (buffer.write_bytes) in one go" {
  let src = "你好👀"
  let buf = @buffer.new(size_hint=src.to_bytes().length())
  buf.write_bytes(src.to_bytes())
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x60\x4f\x7d\x59\x3d\xd8\x40\xdc"
    ,
  )
  let decoder = @encoding.decoder(UTF16LE)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content=src)
}

///|
test "decoding String (UTF16LE encoded) to String (buffer.write_char) in one go" {
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
  let decoder = @encoding.decoder(UTF16LE)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content=src)
}

///|
test "decoding UTF16LE encoded data to String in one go" {
  let buf = @buffer.new(size_hint=10)
  buf.write_bytes(b"\x60\x4f") // 你
  buf.write_bytes(b"\x7d\x59") // 好
  buf.write_bytes(b"\x3d\xd8\x40\xdc") // 👀
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\x60\x4f\x7d\x59\x3d\xd8\x40\xdc"
    ,
  )
  let decoder = @encoding.decoder(UTF16LE)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content="你好👀")
}

///|
test "decoding UTF16 (alias for UTF16LE) encoded data to String in one go" {
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
  let decoder = @encoding.decoder(UTF16)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content="ᡥᠠᡳᡤᡳᠶᠠ")
}

///|
test "decoding UTF16BE encoded data to String in one go" {
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
  let decoder = @encoding.decoder(UTF16BE)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content="🐈🐱🐇🐰")
}

///|
test "decoding UTF8 encoded data to String in one go" {
  let buf = @buffer.new(size_hint=10)
  buf.write_bytes(b"\xe4\xbd\xa0") // 你
  buf.write_bytes(b"\xe5\xa5\xbd") // 好
  buf.write_bytes(b"\xf0\x9f\x91\x80") // 👀
  inspect!(
    buf.to_bytes(),
    content=
      #|b"\xe4\xbd\xa0\xe5\xa5\xbd\xf0\x9f\x91\x80"
    ,
  )
  let decoder = @encoding.decoder(UTF8)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content="你好👀")
}

///|
test "decoding UTF8 encoded bytes to String in one go" {
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
  let decoder = @encoding.decoder(UTF8)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars, content=src)
}

///|
test "decoding UTF8 encoded data in one go" {
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
  let decoder = @encoding.decoder(UTF8)
  let chars = decoder.decode!(buf.to_bytes())
  inspect!(chars.iter().collect(), content="['👋', '再', '见']")
}

///|
test "panic decoding UTF16LE encoded data with UTF8 in one go" {
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
  let decoder = @encoding.decoder(UTF8)
  // FIXME: how to U_REP?
  decoder.decode!(buf.to_bytes()) |> ignore
  // inspect!(
  //   chars.iter().collect(),
  //   content="['э', 'e', 'k', '<', '�', '�', 'n', '�', '�']",
  // )
}

///|
test "decoding UTF8 encoded data with UTF16LE in one go" {
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
  let decoder = @encoding.decoder(UTF16LE)
  let chars = decoder.decode!(buf.to_bytes())
  // NOTE: Happens to be legal UTF16LE
  inspect!(
    chars.iter().collect(),
    content="['럨', '', 'ꖭ', '鿰', '莏', '룦', '', '뎳', '鿰', '誏']",
  )
}

///|
test "decoding UTF16BE encoded data with UTF8 in one go" {
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
  let decoder = @encoding.decoder(UTF8)
  let chars = decoder.decode!(buf.to_bytes())
  // NOTE: decoder generates `Refill` and waits for continued input,
  //       so here is an empty string (`String::default()`)
  inspect!(chars, content="")
}

///|
test "decoding UTF8 encoded data with UTF16BE in one go" {
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
  let decoder = @encoding.decoder(UTF16BE)
  let chars = decoder.decode!(buf.to_bytes())
  // NOTE: Happens to be legal UTF16BE
  inspect!(
    chars.to_array(),
    content="['', '釦', '궥', '', '较', '', '룦', '뎳', '', '辊']",
  )
}

///|
test "decoding UTF16LE encoded data with UTF16BE in one go" {
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
  let decoder = @encoding.decoder(UTF16BE)
  let chars = decoder.decode!(buf.to_bytes())
  // NOTE: Happens to be legal UTF16BE
  inspect!(
    chars.to_array(),
    content="['톍', '敫', '㳘', '쏟', '㡮', '', '㳘', '쫟']",
  )
}

///|
test "decoding UTF16BE encoded data with UTF16LE in one go" {
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
  let decoder = @encoding.decoder(UTF16LE)
  let chars = decoder.decode!(buf.to_bytes())
  // NOTE: Happens to be legal UTF16LE
  inspect!(
    chars.to_array(),
    content="['톍', '敫', '㳘', '쏟', '㡮', '', '㳘', '쫟']",
  )
}

///| https://learn.microsoft.com/en-us/windows/win32/intl/surrogates-and-supplementary-characters
/// > The first (high) surrogate is a 16-bit code value in the range U+D800 to U+DBFF.
/// > The second (low) surrogate is a 16-bit code value in the range U+DC00 to U+DFFF.
test "Not all UTF16LE is format-legal UTF16BE and vice versa" {
  let bytes_le = b"\xD8\x00\xD9\x00"

  // valid in UTF16LE
  let decoder_utf16le = @encoding.decoder(UTF16LE)
  let chars_utf16le = decoder_utf16le.decode!(bytes_le)
  inspect!(chars_utf16le, content="ØÙ")

  // invalid in UTF16BE
  let decoder_utf16be = @encoding.decoder(UTF16BE)
  let malformedError = decoder_utf16be.decode?(bytes_le)
  assert_true!(malformedError.is_err())

  // vice versa
  let bytes_be = b"\x00\xD8\x00\xD9"

  // valid in UTF16BE
  let decoder_utf16be = @encoding.decoder(UTF16BE)
  let chars_utf16be = decoder_utf16be.decode!(bytes_be)
  inspect!(chars_utf16be, content="ØÙ")

  // invalid in UTF16LE
  let decoder_utf16le = @encoding.decoder(UTF16LE)
  let malformedError = decoder_utf16le.decode?(bytes_be)
  assert_true!(malformedError.is_err())
}

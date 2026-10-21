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
test "decode preserves incomplete groups and permissive padding" {
  // These are the existing x semantics, including ignored suffixes after '='.
  // Optimizing the decoder must not silently adopt core's stricter validation.
  for
    (text, expected) in [
      ("", b""),
      ("Z", b""),
      ("Zg", b"f"),
      ("Zg=", b"f"),
      ("Zg==", b"f"),
      ("Zh==", b"f"), // Nonzero unused bits are currently accepted.
      ("Zm8", b"fo"),
      ("Zm9=", b"fo"),
      ("Zm9vZ", b"foo"),
      ("Zg=ignored😀", b"f"),
      ("Zm8=ignored😀", b"fo"),
    ] {
    for url_safe in [false, true] {
      assert_eq(decode(text, url_safe~), expected)
    }
  }
  for text in ["=", "Z=", "Zm9v=", "Zm9vZ="] {
    try decode(text) catch {
      InvalidChar(ch) => assert_eq(ch, '=')
    } noraise {
      _ => fail("expected InvalidChar('=')")
    }
  }
}

///|
test "standard and URL-safe alphabets remain distinct" {
  let bytes : Bytes = [0xFB, 0xFF]
  assert_eq(encode(bytes), "+/8=")
  assert_eq(encode(bytes, url_safe=true), "-_8=")
  assert_eq(decode("+/8="), bytes)
  assert_eq(decode("-_8=", url_safe=true), bytes)
  for
    (text, url_safe, expected) in [
      ("-_8=", false, '-'),
      ("+/8=", true, '+'),
      ("__8=", false, '_'),
      ("//8=", true, '/'),
    ] {
    try decode(text, url_safe~) catch {
      InvalidChar(ch) => assert_eq(ch, expected)
    } noraise {
      _ => fail("expected InvalidChar for the other alphabet")
    }
  }
}

///|
test "invalid Unicode reports the complete character at every block position" {
  for position in 0..<70 {
    let prefix = "A".repeat(position)
    for ch in ['😀', '中', '\uFFFF', '\u0000', ' ', '\n'] {
      let text = "prefix" + prefix + ch.to_string() + "AAAA"
      for url_safe in [false, true] {
        try decode(text[6:], url_safe~) catch {
          InvalidChar(actual) => assert_eq(actual, ch)
        } noraise {
          _ => fail("expected InvalidChar")
        }
      }
    }
  }
}

///|
test "streaming retains partial groups across calls, padding, and errors" {
  let decoder = Decoder::new()
  let out : Array[Byte] = []
  for
    (chunk, expected) in [
      ("Z", b""),
      ("m", b"f"),
      ("=", b"f"), // Padding stops this call without discarding its state.
      ("9", b"fo"),
      ("v", b"foo"),
    ] {
    decoder.decode_to(chunk, byte => out.push(byte))
    assert_eq(Bytes::from_array(out), expected)
  }
  // Invalid input must neither emit a byte nor change the partial group.
  decoder.decode_to("Z", byte => out.push(byte))
  try decoder.decode_to("😀", byte => out.push(byte)) catch {
    InvalidChar(ch) => assert_eq(ch, '😀')
  } noraise {
    _ => fail("expected InvalidChar")
  }
  assert_eq(Bytes::from_array(out), b"foo")
  decoder.decode_to("m9v", byte => out.push(byte))
  assert_eq(Bytes::from_array(out), b"foofoo")
}

///|
test "streaming splits every encoded group correctly" {
  let bytes = Bytes::makei(67, i => (i * 37).to_byte())
  for url_safe in [false, true] {
    let text = encode(bytes, url_safe~)
    for split in 0..<=text.length() {
      let decoder = Decoder::new()
      let out : Array[Byte] = []
      decoder.decode_to(text[:split], byte => out.push(byte), url_safe~)
      decoder.decode_to(text[split:], byte => out.push(byte), url_safe~)
      assert_eq(Bytes::from_array(out), bytes)
    }
    for split in 0..<=bytes.length() {
      let encoder = Encoder::new()
      let out = StringBuilder()
      encoder.encode_to(bytes[:split], ch => out.write_char(ch), url_safe~)
      encoder.encode_to(
        bytes[split:],
        ch => out.write_char(ch),
        url_safe~,
        padding=true,
      )
      assert_eq(out.to_string(), text)
    }
  }
}

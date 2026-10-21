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
fn sample_bytes(length : Int32) -> Bytes {
  // A deterministic mixture covers all byte values and sextet classes.
  let mut state = 0x2545F491U
  Bytes::makei(length, _ => {
    state = state * 1664525U + 1013904223U
    (state >> 16).to_byte()
  })
}

///|
fn compare_decoding(text : StringView, url_safe : Bool) -> Unit raise {
  let fast = Ok(decode(text, url_safe~)) catch {
    InvalidChar(ch) => Err(ch.to_int())
  }
  let scalar = Ok(decode_scalar(text, url_safe~)) catch {
    InvalidChar(ch) => Err(ch.to_int())
  }
  assert_eq(fast, scalar)
}

///|
test "whole-input paths agree with streaming across block sizes and view offsets" {
  for length in 0..<200 {
    let bytes = sample_bytes(length)
    for prefix_length in [0, 1, 7, 16] {
      let padded = Bytes::make(prefix_length, b'!') + bytes + b"suffix"
      let view = padded[prefix_length:prefix_length + length]
      for url_safe in [false, true] {
        let text = encode_scalar(view, url_safe~)
        assert_eq(encode(view, url_safe~), text)
        assert_eq(decode(text, url_safe~), bytes)
        let padded = "!".repeat(prefix_length) + text + "suffix"
        compare_decoding(
          padded[prefix_length:prefix_length + text.length()],
          url_safe,
        )
        // Includes every unpadded remainder and an incomplete trailing sextet.
        for trim in 0..<=3 {
          if trim <= text.length() {
            compare_decoding(text[:text.length() - trim], url_safe)
          }
        }
      }
    }
  }
}

///|
test "whole-input paths agree with streaming on large inputs" {
  for length in [1023, 1024, 1025, 4096, 65536] {
    let bytes = sample_bytes(length)
    for url_safe in [false, true] {
      let text = encode_scalar(bytes, url_safe~)
      assert_eq(encode(bytes, url_safe~), text)
      assert_eq(decode(text, url_safe~), bytes)
      compare_decoding(text, url_safe)
    }
  }
}

///|
test "scalar continuation preserves the decoded prefix and padding behavior" {
  let prefix = sample_bytes(96)
  for url_safe in [false, true] {
    let encoded = encode_scalar(prefix, url_safe~)
    for
      (tail, expected) in [
        ("Z", b""),
        ("Zg", b"f"),
        ("Zg==", b"f"),
        ("Zm8=", b"fo"),
        ("Zg=" + "!".repeat(29), b"f"),
        ("Zm8=" + "!".repeat(28), b"fo"),
        ("Zh==" + "!".repeat(28), b"f"),
      ] {
      let text = "prefix" + encoded + tail + "suffix"
      let input = text[6:6 + encoded.length() + tail.length()]
      assert_eq(decode(input, url_safe~), prefix + expected)
    }
  }
}

///|
test "scalar continuation reports the first invalid character after full blocks" {
  let prefix = sample_bytes(96)
  for url_safe in [false, true] {
    let encoded = encode_scalar(prefix, url_safe~)
    for position in [0, 7, 8, 15, 16, 31] {
      for ch in ['$', '中', '😀'] {
        let body = encoded + "A".repeat(position) + ch.to_string()
        // Keep the length divisible by four to exercise SIMD before the error;
        // a second invalid character must not replace the first reported one.
        let body = body + "!".repeat(32 - body.length() % 4)
        let text = "prefix" + body + "suffix"
        try decode(text[6:6 + body.length()], url_safe~) catch {
          InvalidChar(actual) => assert_eq(actual, ch)
        } noraise {
          _ => fail("expected the first invalid character")
        }
      }
    }
  }
}

///|
#cfg(any(target="native", target="wasm"))
test "SIMD decoder handles full blocks for both alphabets" {
  for length in 24..<67 {
    let bytes = sample_bytes(length)
    for url_safe in [false, true] {
      let text = encode_scalar(bytes, url_safe~)
      assert_eq(decode_v128(text, url_safe), bytes)
    }
  }
}

///|
test "padding, invalid alphabets, and Unicode at every vector and tail position" {
  for length in 30..<40 {
    let bytes = sample_bytes(length)
    for url_safe in [false, true] {
      let chars = encode_scalar(bytes, url_safe~).to_array()
      for position in 0..<chars.length() {
        let saved = chars[position]
        for
          replacement in [
            '=', '$', ' ', '\n', '\u0000', '😀', '中', 'ÿ', 'Ł', '\uFFFF', '+',
            '/', '-', '_',
          ] {
          chars[position] = replacement
          compare_decoding(String::from_array(chars), url_safe)
        }
        chars[position] = saved
      }
    }
  }
}

///|
test "vector narrowing never turns non-ASCII code units into valid Base64" {
  // Deliberately include unpaired surrogates as well as values whose low byte
  // looks like ASCII. String::from_array would hide the raw UTF-16 cases.
  for code in [0x0141, 0x7FFF, 0x8000, 0xD800, 0xDC00, 0xFF41, 0xFFFF] {
    for position in [0, 7, 8, 15, 16, 31, 32, 59, 60, 63] {
      let raw = Bytes::makei(128, i => {
        let unit = if i / 2 == position { code } else { 65 }
        (if i % 2 == 0 { unit } else { unit >> 8 }).to_byte()
      })
      let text = raw.to_unchecked_string()
      for url_safe in [false, true] {
        try decode(text, url_safe~) catch {
          InvalidChar(ch) => assert_eq(ch.to_int(), code)
        } noraise {
          _ => fail("expected InvalidChar for the original code unit")
        }
      }
    }
  }
}

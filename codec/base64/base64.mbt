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

// Base 64 encoding and decoding
// This implementation follows RFC 4648 for  encoding and decoding.

///|
/// index is between 0 and 63, inclusive.
fn index_to_char(index : Int32, url_safe : Bool) -> Char {
  match index {
    0..<26 => (index + 'A').unsafe_to_char()
    26..<52 => (index - 26 + 'a').unsafe_to_char()
    52..<62 => (index - 52 + '0').unsafe_to_char()
    62 => if url_safe { '-' } else { '+' }
    63 => if url_safe { '_' } else { '/' }
    _ => panic()
  }
}

///|
// Return a sextet for the selected alphabet, or -1 for an invalid code unit.
fn base64_value(code : Int32, url_safe : Bool) -> Int32 {
  match code {
    'A'..<='Z' => code - 'A'
    'a'..<='z' => code - 'a' + 26
    '0'..<='9' => code - '0' + 52
    '-' if url_safe => 62
    '+' if !url_safe => 62
    '_' if url_safe => 63
    '/' if !url_safe => 63
    _ => -1
  }
}

///|
struct Encoder {
  mut i : Int32
  mut buffer : Int32
}

///|
pub fn Encoder::new() -> Encoder {
  { i: 0, buffer: 0, }
}

///|
#locals(cb)
pub fn Encoder::encode_to(
  self : Encoder,
  bytes : BytesView,
  cb : (Char) -> Unit,
  url_safe~ : Bool = false,
  padding~ : Bool = false,
) -> Unit {
  for byte in bytes {
    let byte = byte.to_int()
    match self.i {
      0 => {
        cb(index_to_char(byte >> 2, url_safe))
        self.buffer = (byte & 0b11) << 4
        self.i = 1
      }
      1 => {
        cb(index_to_char(self.buffer | (byte >> 4), url_safe))
        self.buffer = (byte & 0b1111) << 2
        self.i = 2
      }
      2 => {
        cb(index_to_char(self.buffer | (byte >> 6), url_safe))
        cb(index_to_char(byte & 0b111111, url_safe))
        self.buffer = 0
        self.i = 0
      }
      _ => panic()
    }
  }
  if padding {
    match self.i {
      0 => ()
      1 => {
        cb(index_to_char(self.buffer, url_safe))
        cb('=')
        cb('=')
      }
      2 => {
        cb(index_to_char(self.buffer, url_safe))
        cb('=')
      }
      _ => panic()
    }
    self.i = 0
  }
}

///|
/// Encode binary to ascii text following  defined in RFC 4648
fn encode_scalar(bytes : BytesView, url_safe~ : Bool = false) -> String {
  let builder = StringBuilder()
  let encoder = Encoder::new()
  encoder.encode_to(
    bytes,
    fn(ch) { builder.write_char(ch) },
    url_safe~,
    padding=true,
  )
  builder.to_string()
}

///|
struct Decoder {
  mut i : Int32
  mut buffer : Int32
}

///|
pub fn Decoder::new() -> Decoder {
  { i: 0, buffer: 0, }
}

///|
#locals(cb)
pub fn Decoder::decode_to(
  self : Decoder,
  input : StringView,
  cb : (Byte) -> Unit,
  url_safe~ : Bool = false,
) -> Unit raise DecodeError {
  for position, code in input.code_units() {
    if code == '=' && self.i >= 2 {
      break
    }
    let idx = base64_value(code.to_int(), url_safe)
    guard idx >= 0 else {
      // The preceding code units are ASCII, so position begins a character.
      raise InvalidChar(input[position:].iter().next().unwrap())
    }
    match self.i {
      0 => {
        self.buffer = idx << 2
        self.i = 1
      }
      1 => {
        cb((self.buffer | (idx >> 4)).to_byte())
        self.buffer = (idx & 0b1111) << 4
        self.i = 2
      }
      2 => {
        cb((self.buffer | (idx >> 2)).to_byte())
        self.buffer = (idx & 0b11) << 6
        self.i = 3
      }
      _ => {
        cb((self.buffer | idx).to_byte())
        self.buffer = 0
        self.i = 0
      }
    }
  }
}

///|
fn decode_scalar(
  input : StringView,
  url_safe~ : Bool = false,
) -> Bytes raise DecodeError {
  let decoder = Decoder::new()
  let output = FixedArray::make(input.length() * 3 / 4, b'\x00')
  let mut i = 0
  decoder.decode_to(
    input,
    fn(byte) {
      output[i] = byte
      i += 1
    },
    url_safe~,
  )
  Bytes::from_array(output[:i])
}

///|
pub suberror DecodeError {
  InvalidChar(Char)
} derive(Debug)

///|
#deprecated
pub extend DecodeError with Debug::{to_repr}

///|
/// Encode binary as padded Base64, optionally using the URL-safe alphabet.
#cfg(any(target="native", target="wasm"))
pub fn encode(bytes : BytesView, url_safe~ : Bool = false) -> String {
  encode_v128(bytes, url_safe)
}

///|
/// Encode binary as padded Base64, optionally using the URL-safe alphabet.
#cfg(not(any(target="native", target="wasm")))
pub fn encode(bytes : BytesView, url_safe~ : Bool = false) -> String {
  encode_scalar(bytes, url_safe~)
}

///|
#cfg(any(target="native", target="wasm"))
pub fn decode(
  input : StringView,
  url_safe~ : Bool = false,
) -> Bytes raise DecodeError {
  decode_v128(input, url_safe)
}

///|
#cfg(not(any(target="native", target="wasm")))
pub fn decode(
  input : StringView,
  url_safe~ : Bool = false,
) -> Bytes raise DecodeError {
  decode_scalar(input, url_safe~)
}

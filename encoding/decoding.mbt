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
const U_REP = '\u{FFFD}'

///|
let utf_8_len = [
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4,
  4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

///|
/// Decodes bytes from a specified encoding into lossily decoded characters.
///
/// # Parameters
/// - `encoding`: The character encoding of the input `bytes`.
/// - `src`: A `bytes` representing the encoded string in the specified format.
///
/// # Returns
///
/// A `LossyChars` iterator representing the decoded characters, with invalid byte sequences replaced by a replacement character.
///
/// # Behavior
///
/// - Any invalid sequences in the `bytes` are replaced with a replacement character (`\u{FFFD}`), preventing decoding errors.
///
/// # Examples
///
/// ```moonbit
/// let buf = @buffer.new(size_hint=10)
/// buf.write_bytes(b"\xe4\xbd\xa0") // "你" in UTF8
/// buf.write_bytes(b"\xe5\xa5\xbd") // "好" in UTF8
/// buf.write_bytes(b"\xf0\x9f\x91\x80") // "👀" in UTF8
/// let chars = @encoding.decode_lossy(UTF8, buf.to_bytes())
/// let arr = chars.iter().collect() // Array of unicode point code: `['你', '好', '👀']`
/// let str = String::from_array(arr) // MoonBit String, representing as UTF16LE: `"你好👀"`
/// // or
/// let str = chars.to_string()
/// ```
pub fn decode_lossy(encoding : Encoding, src : Bytes) -> LossyChars {
  let decoder = decoder(encoding, src)
  decoder
}

///|
/// Decodes bytes from a specified encoding into strictly decoded characters.
///
/// # Parameters
///
/// - `encoding`: The character encoding of the input `bytes`.
/// - `src`: A `bytes` representing the encoded string in the specified format.
///
/// # Returns
///
/// A `StrictChars` iterator representing the decoded characters.
///
/// # Behavior
///
/// - Assumes all sequences in the `bytes` are valid and will raise errors if invalid sequences are encountered.
///
/// # Examples
///
/// ```moonbit
/// let buf = @buffer.new(size_hint=10)
/// buf.write_bytes(b"\xe4\xbd\xa0") // "你" in UTF8
/// buf.write_bytes(b"\xe5\xa5\xbd") // "好" in UTF8
/// buf.write_bytes(b"\xf0\x9f\x91\x80") // "👀" in UTF8
/// let chars = @encoding.decode_strict(UTF8, buf.to_bytes())
/// let arr = chars.iter().collect() // Array of unicode point code: `[Ok('你'), Ok('好'), Ok('👀')]`
/// let str = chars.to_string() // MoonBit String, representing as UTF16LE: `"你好👀"`
/// ```
pub fn decode_strict(encoding : Encoding, src : Bytes) -> StrictChars {
  let decoder = decoder(encoding, src)
  decoder
}

// Implementations

///|
fn decoder(encoding : Encoding, src : Bytes) -> Decoder {
  let i = src.to_fixedarray()
  let i_pos = 0
  let i_max = src.length() - 1
  let t = b"\x00\x00\x00\x00".to_fixedarray()
  let t_len = 0
  let t_need = 0
  let k = match encoding {
    UTF8 => decode_utf_8
    UTF16 => decode_utf_16le
    UTF16LE => decode_utf_16le
    UTF16BE => decode_utf_16be
  }
  { i, i_pos, i_max, t, t_len, t_need, k }
}

///|
fn decode(self : Decoder) -> Decode {
  (self.k)(self)
}

///|
fn ret(self : Decoder, k : Cont, v : Decode) -> Decode {
  self.k = k
  v
}

///|
fn i_rem(self : Decoder) -> Int {
  self.i_max - self.i_pos + 1
}

///|
fn eoi(self : Decoder) -> Unit {
  self.i = []
  self.i_pos = 0
  self.i_max = @int.min_value
}

///|
fn refill(self : Decoder, k : Cont) -> Decode {
  // only Bytes
  self.eoi()
  k(self)
}

///|
fn t_need(self : Decoder, need : Int) -> Unit {
  self.t_len = 0
  self.t_need = need
}

///|
fn t_fill(k : Cont, decoder : Decoder) -> Decode {
  fn blit(decoder : Decoder, l : Int) -> Unit {
    FixedArray::unsafe_blit(
      decoder.i,
      decoder.i_pos,
      decoder.t,
      decoder.t_len,
      l,
    )
    decoder.i_pos = decoder.i_pos + 1
    decoder.t_len = decoder.t_len + 1
  }

  let rem = decoder.i_rem()
  if rem < 0 { // eoi
    k(decoder)
  } else {
    let need = decoder.t_need - decoder.t_len
    if rem < need {
      blit(decoder, rem)
      decoder.refill(@tuple.curry(t_fill)(k))
    } else {
      blit(decoder, need)
      k(decoder)
    }
  }
}

// UTF8

///|
fn decode_utf_8(self : Decoder) -> Decode {
  let rem = self.i_rem()
  match rem.compare(0) {
    // rem < 0
    -1 => Decode::End
    // rem = 0
    0 => self.refill(decode_utf_8)
    // rem > 0
    1 => {
      let idx = self.i[self.i_pos].to_int()
      let need = utf_8_len[idx]
      if rem < need {
        self.t_need(need)
        t_fill(t_decode_utf_8, self)
      } else {
        let j = self.i_pos
        if need == 0 {
          self.i_pos = self.i_pos + 1
          self.ret(
            decode_utf_8,
            malformed(Bytes::from_fixedarray(self.i), j, 1),
          )
        } else {
          self.i_pos = self.i_pos + need
          self.ret(
            decode_utf_8,
            r_utf_8(Bytes::from_fixedarray(self.i), j, need),
          )
        }
      }
    }
    _ => abort("unreachable")
  }
}

///|
fn t_decode_utf_8(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    malformed(Bytes::from_fixedarray(self.t), 0, self.t_len)
  } else {
    r_utf_8(Bytes::from_fixedarray(self.t), 0, self.t_len)
  }
}

///|
fn r_utf_8(bytes : Bytes, offset : Int, length : Int) -> Decode {
  fn uchar(c : Int) {
    Uchar(Char::from_int(c))
  }

  match length {
    1 => uchar(bytes[offset].to_int())
    2 => {
      let b0 = bytes[offset].to_int()
      let b1 = bytes[offset + 1].to_int()
      if (b1 >> 6) != 0b10 {
        malformed(bytes, offset, length)
      } else {
        uchar(((b0 & 0x1F) << 6) | (b1 & 0x3F))
      }
    }
    3 => {
      let b0 = bytes[offset].to_int()
      let b1 = bytes[offset + 1].to_int()
      let b2 = bytes[offset + 2].to_int()
      let c = ((b0 & 0x0F) << 12) | (((b1 & 0x3F) << 6) | (b2 & 0x3F))
      if (b2 >> 6) != 0b10 {
        malformed(bytes, offset, length)
      } else {
        match b0 {
          0xE0 =>
            if b1 < 0xA0 || 0xBF < b1 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
          0xED =>
            if b1 < 0x80 || 0x9F < b1 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
          _ =>
            if (b1 >> 6) != 0b10 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
        }
      }
    }
    4 => {
      let b0 = bytes[offset].to_int()
      let b1 = bytes[offset + 1].to_int()
      let b2 = bytes[offset + 2].to_int()
      let b3 = bytes[offset + 3].to_int()
      let c = ((b0 & 0x07) << 18) |
        ((b1 & 0x3F) << 12) |
        ((b2 & 0x3F) << 6) |
        (b3 & 0x3F)
      if (b3 >> 6) != 0b10 || (b2 >> 6) != 0b10 {
        malformed(bytes, offset, length)
      } else {
        match b0 {
          0xF0 =>
            if b1 < 0x90 || 0xBF < b1 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
          0xF4 =>
            if b1 < 0x80 || 0x8F < b1 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
          _ =>
            if (b1 >> 6) != 0b10 {
              malformed(bytes, offset, length)
            } else {
              uchar(c)
            }
        }
      }
    }
    _ => panic()
  }
}

// UTF16LE

///|
priv enum UTF16Decode {
  Hi(Int)
  UTF16Malformed(Bytes)
  UTF16Uchar(Char)
}

///|
fn decode_utf_16le(self : Decoder) -> Decode {
  let rem = self.i_rem()
  match rem.compare(0) {
    // rem < 0
    -1 => Decode::End
    // rem = 0
    0 => self.refill(decode_utf_16le)
    // rem > 0
    1 =>
      if rem < 2 {
        self.t_need(2)
        t_fill(t_decode_utf_16le, self)
      } else {
        let j = self.i_pos
        self.i_pos = self.i_pos + 2
        // mark
        self.decode_utf_16le_lo(
          r_utf_16(Bytes::from_fixedarray(self.i), j + 1, j),
        )
      }
    _ => abort("unreachable")
  }
}

///|
fn t_decode_utf_16le(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(
      decode_utf_16le,
      malformed(Bytes::from_fixedarray(self.t), 0, self.t_len),
    )
  } else {
    self.decode_utf_16le_lo(r_utf_16(Bytes::from_fixedarray(self.t), 1, 0))
  }
}

///|
fn decode_utf_16le_lo(self : Decoder, v : UTF16Decode) -> Decode {
  match v {
    UTF16Uchar(u) => Uchar(u)
    UTF16Malformed(s) => Malformed(s)
    Hi(hi) => {
      let rem = self.i_rem()
      if rem < 2 {
        self.t_need(2)
        t_fill(@tuple.curry(t_decode_utf_16le_lo)(hi), self)
      } else {
        let j = self.i_pos
        self.i_pos = self.i_pos + 2
        r_utf_16_lo(hi, Bytes::from_fixedarray(self.i), j + 1, j)
      }
    }
  }
}

///|
fn t_decode_utf_16le_lo(hi : Int, decoder : Decoder) -> Decode {
  if decoder.t_len < decoder.t_need {
    decoder.ret(
      decode_utf_16le,
      malformed_pair(
        false,
        hi,
        Bytes::from_fixedarray(decoder.t),
        0,
        decoder.t_len,
      ),
    )
  } else {
    decoder.ret(
      decode_utf_16le,
      r_utf_16_lo(hi, Bytes::from_fixedarray(decoder.t), 1, 0),
    )
  }
}

///|
fn r_utf_16_lo(hi : Int, bytes : Bytes, offset0 : Int, offset1 : Int) -> Decode {
  let b0 = bytes[offset0].to_int()
  let b1 = bytes[offset1].to_int()
  let lo = (b0 << 8) | b1
  if lo < 0xDC00 || lo > 0xDFFF {
    malformed_pair(
      offset0 < offset1,
      hi,
      bytes,
      @math.minimum(offset0, offset1),
      2,
    )
  } else {
    Uchar(Char::from_int(((hi & 0x3FF) << 10) | ((lo & 0x3FF) + 0x10000)))
  }
}

///|
fn r_utf_16(bytes : Bytes, offset0 : Int, offset1 : Int) -> UTF16Decode {
  let b0 = bytes[offset0].to_int()
  let b1 = bytes[offset1].to_int()
  let u = (b0 << 8) | b1
  if u < 0xD800 || u > 0xDFFF {
    UTF16Uchar(Char::from_int(u))
  } else if u > 0xDBFF {
    UTF16Malformed(slice(bytes, @math.minimum(offset0, offset1), 2))
  } else {
    Hi(u)
  }
}

// UTF16BE

///|
fn decode_utf_16be(self : Decoder) -> Decode {
  let rem = self.i_rem()
  match rem.compare(0) {
    // rem < 0
    -1 => Decode::End
    // rem = 0
    0 => self.refill(decode_utf_16be)
    // rem > 0
    1 =>
      if rem < 2 {
        self.t_need(2)
        t_fill(t_decode_utf_16be, self)
      } else {
        let j = self.i_pos
        self.i_pos = self.i_pos + 2
        self.decode_utf_16be_lo(
          r_utf_16(Bytes::from_fixedarray(self.i), j, j + 1),
        )
      }
    _ => abort("unreachable")
  }
}

///|
fn t_decode_utf_16be(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(
      decode_utf_16be,
      malformed(Bytes::from_fixedarray(self.t), 0, self.t_len),
    )
  } else {
    self.decode_utf_16be_lo(r_utf_16(Bytes::from_fixedarray(self.t), 0, 1))
  }
}

///|
fn decode_utf_16be_lo(self : Decoder, decode : UTF16Decode) -> Decode {
  match decode {
    UTF16Uchar(x) => self.ret(decode_utf_16be, Uchar(x))
    UTF16Malformed(x) => self.ret(decode_utf_16be, Malformed(x))
    Hi(hi) => {
      let rem = self.i_rem()
      if rem < 2 {
        self.t_need(2)
        t_fill(@tuple.curry(t_decode_utf_16be_lo)(hi), self)
      } else {
        let j = self.i_pos
        self.i_pos = self.i_pos + 2
        self.ret(
          decode_utf_16be,
          r_utf_16_lo(hi, Bytes::from_fixedarray(self.i), j, j + 1),
        )
      }
    }
  }
}

///|
fn t_decode_utf_16be_lo(hi : Int, self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(
      decode_utf_16be,
      malformed_pair(true, hi, Bytes::from_fixedarray(self.t), 0, self.t_len),
    )
  } else {
    self.ret(
      decode_utf_16be,
      r_utf_16_lo(hi, Bytes::from_fixedarray(self.t), 0, 1),
    )
  }
}

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
pub const U_REP = '\u{FFFD}'

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
pub fn decoder(encoding : Encoding) -> Decoder {
  let i = FixedArray::default()
  let i_pos = 0
  let t = FixedArray::make(4, Byte::default())
  let t_len = 0
  let t_need = 0
  let k = match encoding {
    UTF8 => decode_utf_8
    UTF16 => decode_utf_16le
    UTF16LE => decode_utf_16le
    UTF16BE => decode_utf_16be
  }
  { i, i_pos, t, t_len, t_need, k }
}

///|
pub fn decode!(self : Decoder, input : Bytes, stream~ : Bool = true) -> String {
  self.i_cont(input)

  // drive decoder to decode
  let chars = []
  loop self.decode_() {
    Uchar(u) => {
      chars.push(u)
      continue self.decode_()
    }
    Malformed(bs) =>
      if stream && self.t_need > 0 {
        String::from_array(chars)
      } else {
        raise MalformedError(bs)
      }
    End => String::from_array(chars)
    Refill(t) =>
      if stream {
        String::from_array(chars)
      } else {
        raise TruncatedError(t)
      }
  }
}

///|
pub fn decode_lossy(
  self : Decoder,
  input : Bytes,
  stream~ : Bool = true
) -> String {
  self.i_cont(input)

  // drive decoder to decode
  let chars = []
  loop self.decode_() {
    Uchar(u) => {
      chars.push(u)
      continue self.decode_()
    }
    Malformed(_) =>
      if stream && self.t_need > 0 {
        String::from_array(chars)
      } else {
        chars.push(U_REP)
        continue self.decode_()
      }
    End => String::from_array(chars)
    Refill(_) =>
      if stream {
        String::from_array(chars)
      } else {
        continue self.decode_()
      }
  }
}

///|
fn i_cont(self : Decoder, input : Bytes) -> Unit {
  // concat `input` to `i`, drop decoded `i`
  let i_rem = @math.maximum(self.i_rem(), 0)
  let new_len = i_rem + input.length()
  // init a new `i`
  let new_i = FixedArray::make(new_len, Byte::default())
  if i_rem > 0 {
    // copy the remainder of the old `i` into the new `i`
    self.i.blit_to(new_i, len=i_rem, src_offset=self.i_pos)
  }
  // copy all `input` into new `i`, starting at the remainder of the old `i`
  new_i.blit_from_bytes(i_rem, input, 0, input.length())
  self.i = new_i
  // reset position to starting position
  self.i_pos = 0
}

// Implementations

///|
fn decode_(self : Decoder) -> Decode {
  (self.k)(self)
}

///|
fn ret(self : Decoder, k : Cont, v : Decode) -> Decode {
  self.k = k
  v
}

///|
fn i_rem(self : Decoder) -> Int {
  self.i.length() - self.i_pos
}

///|
fn t_need(self : Decoder, need : Int) -> Unit {
  self.t_len = 0
  self.t_need = need
}

///|
fn eoi(self : Decoder) -> Unit {
  self.i = FixedArray::default()
}

///|
fn refill(self : Decoder, k : Cont) -> Decode {
  self.eoi()
  self.ret(k, Decode::Refill(Bytes::from_fixedarray(self.t)))
}

///|
fn t_fill(k : Cont, decoder : Decoder) -> Decode {
  fn blit(decoder : Decoder, l : Int) -> Unit {
    decoder.i.blit_to(
      decoder.t,
      len=l,
      dst_offset=decoder.t_len,
      src_offset=decoder.i_pos,
    )
    decoder.i_pos += l
    decoder.t_len += l
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
  if rem <= 0 {
    Decode::End
  } else {
    let idx = self.i[self.i_pos].to_int()
    let need = utf_8_len[idx]
    if rem < need {
      self.t_need(need)
      t_fill(t_decode_utf_8, self)
    } else {
      let j = self.i_pos
      if need == 0 {
        self.i_pos += 1
        self.ret(decode_utf_8, malformed(self.i, j, 1))
      } else {
        self.i_pos += need
        self.ret(decode_utf_8, r_utf_8(self.i, j, need))
      }
    }
  }
}

///|
fn t_decode_utf_8(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(decode_utf_8, malformed(self.t, 0, self.t_len))
  } else {
    self.ret(decode_utf_8, r_utf_8(self.t, 0, self.t_len))
  }
}

///|
fn r_utf_8(bytes : FixedArray[Byte], offset : Int, length : Int) -> Decode {
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
  if rem <= 0 {
    Decode::End
  } else if rem < 2 {
    self.t_need(2)
    t_fill(t_decode_utf_16le, self)
  } else {
    let j = self.i_pos
    self.i_pos += 2
    self.decode_utf_16le_lo(r_utf_16(self.i, j + 1, j))
  }
}

///|
fn t_decode_utf_16le(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(decode_utf_16le, malformed(self.t, 0, self.t_len))
  } else {
    self.decode_utf_16le_lo(r_utf_16(self.t, 1, 0))
  }
}

///|
fn decode_utf_16le_lo(self : Decoder, v : UTF16Decode) -> Decode {
  match v {
    UTF16Uchar(u) => self.ret(decode_utf_16le, Uchar(u))
    UTF16Malformed(s) => self.ret(decode_utf_16le, Malformed(s))
    Hi(hi) => {
      let rem = self.i_rem()
      if rem < 2 {
        self.t_need(2)
        t_fill(@tuple.curry(t_decode_utf_16le_lo)(hi), self)
      } else {
        let j = self.i_pos
        self.i_pos += 2
        self.ret(decode_utf_16le, r_utf_16_lo(hi, self.i, j + 1, j))
      }
    }
  }
}

///|
fn t_decode_utf_16le_lo(hi : Int, decoder : Decoder) -> Decode {
  if decoder.t_len < decoder.t_need {
    decoder.ret(
      decode_utf_16le,
      malformed_pair(false, hi, decoder.t, 0, decoder.t_len),
    )
  } else {
    decoder.ret(decode_utf_16le, r_utf_16_lo(hi, decoder.t, 1, 0))
  }
}

///|
fn r_utf_16_lo(
  hi : Int,
  bytes : FixedArray[Byte],
  offset0 : Int,
  offset1 : Int
) -> Decode {
  let b0 = bytes[offset0].to_int()
  let b1 = bytes[offset1].to_int()
  let lo = (b0 << 8) | b1
  if lo < 0xDC00 || lo > 0xDFFF {
    // TODO(jinser): try to skip lo and then parse the following
    //
    // For example, b"\xD8\x00\x00\x48" (BE)
    // Since \xD8\x00 is *legal* hi, here will try to parse lo next,
    // however the whole \xD8\x00\x00\x48 is *illegal* so the result will be a `Malformed[b"\xD8\x00\x00\x48"]`
    //
    // But \x00\x48 itself is a *legal* UTF16 code point with a value of `H`,
    // the ideal result should be: `[Malformed(b"\xD8\x00"), Uchar('H')]`
    //
    // > printf '\xD8\x00\x00\x48' | uconv --from-code UTF16BE --to-code UTF8 --from-callback substitute
    // �H
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
fn r_utf_16(
  bytes : FixedArray[Byte],
  offset0 : Int,
  offset1 : Int
) -> UTF16Decode {
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
  if rem <= 0 {
    Decode::End
  } else if rem < 2 {
    self.t_need(2)
    t_fill(t_decode_utf_16be, self)
  } else {
    let j = self.i_pos
    self.i_pos += 2
    self.decode_utf_16be_lo(r_utf_16(self.i, j, j + 1))
  }
}

///|
fn t_decode_utf_16be(self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(decode_utf_16be, malformed(self.t, 0, self.t_len))
  } else {
    self.decode_utf_16be_lo(r_utf_16(self.t, 0, 1))
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
        self.i_pos += 2
        self.ret(decode_utf_16be, r_utf_16_lo(hi, self.i, j, j + 1))
      }
    }
  }
}

///|
fn t_decode_utf_16be_lo(hi : Int, self : Decoder) -> Decode {
  if self.t_len < self.t_need {
    self.ret(decode_utf_16be, malformed_pair(true, hi, self.t, 0, self.t_len))
  } else {
    self.ret(decode_utf_16be, r_utf_16_lo(hi, self.t, 0, 1))
  }
}

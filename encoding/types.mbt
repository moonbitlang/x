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
typealias Cont = (Decoder) -> Decode

///|
pub(all) enum Encoding {
  UTF8
  UTF16 // alias for UTF16LE
  UTF16LE
  UTF16BE
}

// Decoder

///|
priv struct Decoder {
  mut i : Bytes
  mut i_pos : Int
  mut i_max : Int
  t : Bytes
  mut t_len : Int
  mut t_need : Int
  mut k : Cont
}

///|
priv enum Decode {
  End
  Malformed(Bytes)
  Uchar(Char)
}

fn slice(bytes : Bytes, offset : Int, length : Int) -> Bytes {
  let new_bytes = Bytes::new(length)
  new_bytes.blit(0, bytes, offset, length)
  new_bytes
}

///|
fn malformed(buf : Bytes, offset : Int, length : Int) -> Decode {
  Malformed(slice(buf, offset, length))
}

///|
fn malformed_pair(
  be : Bool,
  hi : Int,
  buf : Bytes,
  offset : Int,
  length : Int
) -> Decode {
  let bs1 = buf.to_unchecked_string(offset~, length~).to_bytes()
  let bs0 = b"\x00\x00"
  let (j0, j1) = if be { (0, 1) } else { (1, 0) }
  bs0[j0] = (hi >> 8).to_byte()
  bs0[j1] = hi.land(0xFF).to_byte()
  let bs = @buffer.new(size_hint=bs0.length() + bs1.length())
  bs.write_bytes(bs0)
  bs.write_bytes(bs1)
  Malformed(slice(bs.to_bytes(), 0, bs.length()))
}

// Chars

///|
type LossyChars Decoder

///|
pub fn iter(self : LossyChars) -> Iter[Char] {
  Iter::new(
    fn(yield_) {
      loop self._.decode() {
        Uchar(u) => {
          if yield_(u) == IterEnd {
            break IterEnd
          }
          continue self._.decode()
        }
        Malformed(_) => {
          if yield_(U_REP) == IterEnd {
            break IterEnd
          }
          continue self._.decode()
        }
        End => break IterEnd
      }
    },
  )
}

///|
pub fn to_string(self : LossyChars) -> String {
  let arr = self.iter().collect()
  String::from_array(arr)
}

///|
pub impl Show for LossyChars with output(self : LossyChars, logger : Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
type StrictChars Decoder

///|
pub(all) type! DecodeError Bytes

///|
pub impl Show for DecodeError with output(self, logger) {
  match self {
    DecodeError(err) => err.output(logger)
  }
}

///|
pub fn iter(self : StrictChars) -> Iter[Result[Char, DecodeError]] {
  Iter::new(
    fn(yield_) {
      loop self._.decode() {
        Uchar(u) => {
          if yield_(Ok(u)) == IterEnd {
            break IterEnd
          }
          continue self._.decode()
        }
        Malformed(s) => {
          let err = DecodeError(s)
          if yield_(Err(err)) == IterEnd {
            break IterEnd
          }
          continue self._.decode()
        }
        End => break IterEnd
      }
    },
  )
}

///|
pub fn to_string(self : StrictChars) -> String! {
  let arr = []
  for element in self {
    match element {
      Ok(x) => arr.push(x)
      Err(e) => raise e
    }
  }
  String::from_array(arr)
}

///|
pub impl Show for StrictChars with output(self : StrictChars, logger : Logger) -> Unit {
  logger.write_string(self.to_string?().to_string())
}

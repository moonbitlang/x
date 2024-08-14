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

struct UInt128 {
  mut high : UInt64
  mut low : UInt64
} derive(Eq, Show)

pub fn UInt128::zero() -> UInt128 {
  { high: 0, low: 0 }
}

pub fn UInt128::one() -> UInt128 {
  { high: 0, low: 1 }
}

pub fn UInt128::from_int(x : Int) -> UInt128 {
  {
    high: if x < 0 {
      x.lnot().to_int64().to_uint64()
    } else {
      0
    },
    low: x.to_int64().to_uint64(),
  }
}

pub fn UInt128::copy(self : UInt128) -> UInt128 {
  { ..self }
}

/// 2's complement
pub fn UInt128::op_neg(self : UInt128) -> UInt128 {
  let v = { high: self.high.lnot(), low: self.low.lnot() }
  v.incf()
}

pub fn UInt128::op_sub(self : UInt128, other : UInt128) -> UInt128 {
  let v = UInt128::zero()
  v.low = self.low - other.low
  // borrow bit
  let borrow = (
      (self.low.lnot() & other.low) | ((self.low ^ other.low).lnot() & v.low)
    ) >>
    63
  v.high = self.high - other.high - borrow
  v
}

pub fn UInt128::op_add(self : UInt128, other : UInt128) -> UInt128 {
  let v = UInt128::zero()
  v.low = self.low + other.low
  // carry bit
  let carry = (self.low & other.low) |
    (((self.low | other.low) & v.low.lnot()) >> 63)
  v.high = self.high + other.high + carry
  v
}

/// 1+ self
pub fn UInt128::incf(self : UInt128) -> UInt128 {
  let low = self.low + 1UL
  let carry = (self.low & low.lnot()) >> 63
  self.high += carry
  self.low = low
  self
}

pub fn UInt128::decf(self: UInt128) -> UInt128 {
  let low = self.low - 1UL
  let borrow = (self.low.lnot() & low) >> 63
  self.high -= borrow
  self.low = low
  self
}

pub fn UInt128::compare(self : UInt128, other : UInt128) -> Bool {
  if self.high != other.high {
    return self.high < other.high
  } else {
    return self.low < other.low
  }
}

pub fn UInt128::lor(self : UInt128, other : UInt128) -> UInt128 {
  match (self, other) {
    ({ high: 0, low: 0 }, other) => other
    (self, { high: 0, low: 0 }) => self
    _ => {
      let v = self.copy()
      v.high = v.high | other.high
      v.low = v.low | other.low
      v
    }
  }
}

pub fn UInt128::land(self : UInt128, other : UInt128) -> UInt128 {
  match (self, other) {
    ({ high: 0, low: 0 }, other) => other
    (self, { high: 0, low: 0 }) => self
    _ => {
      let v = self.copy()
      v.high = v.high & other.high
      v.low = v.low & other.low
      v
    }
  }
}

pub fn UInt128::lxor(self : UInt128, other : UInt128) -> UInt128 {
  match (self, other) {
    ({ high: 0, low: 0 }, other) => other
    (self, { high: 0, low: 0 }) => self
    _ => {
      let v = self.copy()
      v.high = v.high ^ other.high
      v.low = v.low ^ other.low
      v
    }
  }
}

pub fn UInt128::lnot(self : UInt128) -> UInt128 {
  { high: self.high.lnot(), low: self.low.lnot() }
}

pub fn UInt128::shl(self : UInt128, shift : UInt) -> UInt128 {
  if shift >= 128 {
    UInt128::zero()
  } else {
    self.wrapping_shl(shift)
  }
}

/// left shift but w/ a modulus `shift`. e.g. x << 128 <=> x << 128 mod 128 = x
/// - Has better performance than regular `<<`
pub fn UInt128::wrapping_shl(self : UInt128, shift : UInt) -> UInt128 {
    let mut s = shift & 127
    let p_1 = ((((s + 127) | s) & 64) >> 6).to_uint64() - 1UL
    let p_2 = (s >> 6).to_uint64() - 1UL
    s = s & 63
    let mut high = (self.low << s.to_int()) & p_2.lnot()
    let low = (self.low << s.to_int()) & p_2
    high = high |
      (
        ((self.high << s.to_int()) | ((self.low >> (64 - s.to_int())) & p_1)) &
        p_2
      )
    { high, low }
}

/// right shift but w/ a modulus `shift`. e.g. x >> 128 <=> x >> 128 mod 128 = x
/// - Has better performance than regular `>>`
pub fn UInt128::shr(self : UInt128, shift : UInt) -> UInt128 {
  if shift >= 128 {
    UInt128::zero()
  } else {
    self.wrapping_shr(shift)
  }
}

pub fn UInt128::wrapping_shr(self : UInt128, shift : UInt) -> UInt128 {
    let mut s = shift
    let p_1 = ((((s + 127) | s) & 64) >> 6).to_uint64() - 1UL
    let p_2 = (s >> 6).to_uint64() - 1UL
    s = s & 63
    let mut high = (self.low >> s.to_int()) & p_2.lnot()
    let low = (self.low >> s.to_int()) & p_2
    high = high |
      (
        ((self.high >> s.to_int()) | ((self.low << (64 - s.to_int())) & p_1)) &
        p_2
      )
    { high, low }
}

/// multiply 2 u64 to get a u128
pub fn UInt128::mul64x64(u : UInt64, v : UInt64) -> UInt128 {
  // decompose u64 to 2 u32
  let u_low = u & 0xffffffff
  let u_high = u >> 32
  let v_low = v & 0xffffffff
  let v_high = v >> 32
  let x = u_low * v_low
  let y = u_high * v_low + (x >> 32)
  let z = u_low * v_high + (y & 0xffffffff)
  { high: u_high * v_high + (y >> 32) + (z >> 32), low: u * v }
}

/// multiply 2 u128 to get a u128.
pub fn op_mul(self : UInt128, other : UInt128) -> UInt128 {
  let mul128 = mul64x64(self.low, other.low)
  {
    high: mul128.high + self.high * other.low + self.low * other.high,
    low: mul128.low,
  }
}


/// count `1` bits in a UInt64. See [Bit Twiddling Hacks](http://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel).
pub fn UInt128::popcnt64(u : UInt64) -> Int {
  let mut u_mut = (u >> 1) & 0x5555555555555555
  u_mut = (u_mut & 0x3333333333333333) + ((u_mut >> 2) & 0x3333333333333333)
  return (((u_mut + (u_mut >> 4) & 0xF0F0F0F0F0F0F0F) * 0x101010101010101) >> 56).to_int()
}

/// count `1` bits in a UInt128
pub fn UInt128::popcnt(u: UInt128) -> Int {
  popcnt64(u.high) + popcnt64(u.low)
}

pub fn to_hex_string(self : UInt128) -> String {
  let s = (u64_to_hex_string(self.high) + u64_to_hex_string(self.low)).trim_left(
    "0", // squeeze leading zero
  )
  if s.is_empty() {
    "0"
  } else {
    s
  }
}

/// all 128 bits in 16 bytes
pub fn to_bytes(self : UInt128) -> Bytes {
  let b = Bytes::new(16)
  for index = 0; index < 8; index = index + 1 {
    b[index] = uint64_to_bytesle(self.low)[index]
  }
  for index = 0; index < 8; index = index + 1 {
    b[index + 8] = uint64_to_bytesle(self.high)[index]
  }
  b
}

/// low 8 bits
fn to_byte(self : UInt128) -> Byte {
  self.low.to_byte()
}

// TODO: efficient `Div` that combines Divide and Conquer w/ Binary Shift

test {
  println(
    ({ high: 0xffffffffff123450UL, low: 0xffffffffffffffffUL }.incf()).to_hex_string(),
  )
}

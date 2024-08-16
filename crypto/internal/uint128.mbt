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
} derive(Eq)

pub fn UInt128::zero() -> UInt128 {
  { high: 0, low: 0 }
}

pub fn UInt128::one() -> UInt128 {
  { high: 0, low: 1 }
}

pub fn UInt128::max() -> UInt128 {
  { high: 0xffff_ffff_ffff_ffffUL, low: 0xffff_ffff_ffff_ffffUL }
}

pub fn UInt128::from_uint(x : UInt) -> UInt128 {
  { high: 0, low: x.to_uint64() }
}

pub fn UInt128::from_bin_string(s : String) -> UInt128 {
  try_parse?(s, radix=Bin).unwrap()
}

pub fn UInt128::from_oct_string(s : String) -> UInt128 {
  try_parse?(s, radix=Oct).unwrap()
}

pub fn UInt128::from_string(s : String) -> UInt128 {
  try_parse?(s).unwrap()
}

pub fn UInt128::from_hex_string(s : String) -> UInt128 {
  try_parse16?(s).unwrap()
}

pub fn UInt128::make(high : UInt64, low : UInt64) -> UInt128 {
  { high, low }
}

test {
  assert_eq!(
    (UInt128::from_uint(0xffffffff) + UInt128::from_uint(0xffffffff)).to_hex_string(),
    "1fffffffe",
  )
}

pub fn UInt128::copy(self : UInt128) -> UInt128 {
  { ..self }
}

/// 2's complement
pub fn UInt128::complement(self : UInt128) -> UInt128 {
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
  let carry = ((self.low & other.low) | ((self.low | other.low) & v.low.lnot())) >>
    63
  v.high = self.high + other.high + carry
  v
}

test {
  assert_eq!(
    UInt128::make(0, 0xffff_ffff_ffff_ffffUL) + UInt128::one(),
    { high: 0x1, low: 0 },
  )
  assert_eq!(
    UInt128::make(1, 0) - UInt128::one(),
    { high: 0, low: 0xffff_ffff_ffff_ffffUL },
  )
  assert_eq!(UInt128::max().complement(), UInt128::one())
}

/// 1+ self
pub fn UInt128::incf(self : UInt128) -> UInt128 {
  let low = self.low + 1UL
  let carry = (self.low & low.lnot()) >> 63
  self.high += carry
  self.low = low
  self
}

/// 1- self
pub fn UInt128::decf(self : UInt128) -> UInt128 {
  let low = self.low - 1UL
  let borrow = (self.low.lnot() & low) >> 63
  self.high -= borrow
  self.low = low
  self
}

pub fn UInt128::compare(self : UInt128, other : UInt128) -> Int {
  if self.high != other.high {
    return self.high.compare(other.high)
  } else {
    return self.low.compare(other.low)
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

pub fn UInt128::op_shl(self : UInt128, shift : Int) -> UInt128 {
  if shift >= 128 {
    UInt128::zero()
  } else {
    self.wrapping_shl(shift.to_uint())
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

test {
  assert_eq!(
    wrapping_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 8).to_hex_string(),
    "11234567890abcdef00",
  )
  assert_eq!(
    wrapping_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 16).to_hex_string(),
    "11234567890abcdef0000",
  )
  assert_eq!(
    wrapping_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 32).to_hex_string(),
    "11234567890abcdef00000000",
  )
  assert_eq!(
    wrapping_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 64).to_hex_string(),
    "1234567890abcdef0000000000000000",
  )
  assert_eq!(
    wrapping_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 128).to_hex_string(),
    "11234567890abcdef",
  )
  assert_eq!(
    op_shl({ high: 1, low: 0x1234_5678_90ab_cdef }, 128).to_hex_string(),
    "0",
  )
}

pub fn UInt128::op_shr(self : UInt128, shift : Int) -> UInt128 {
  if shift >= 128 {
    UInt128::zero()
  } else {
    self.wrapping_shr(shift.to_uint())
  }
}

/// right shift but w/ a modulus `shift`. e.g. x >> 128 <=> x >> 128 mod 128 = x
/// - Has better performance than regular `>>`
pub fn UInt128::wrapping_shr(self : UInt128, shift : UInt) -> UInt128 {
  let mut s = shift & 127
  let p_1 = ((((s + 127) | s) & 64) >> 6).to_uint64() - 1UL
  let p_2 = (s >> 6).to_uint64() - 1UL
  s = s & 63
  let mut low = (self.high >> s.to_int()) & p_2.lnot()
  let high = (self.high >> s.to_int()) & p_2
  low = low |
    (
      ((self.low >> s.to_int()) | ((self.high << (64 - s.to_int())) & p_1)) &
      p_2
    )
  { high, low }
}

test {
  assert_eq!(
    wrapping_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 8).to_hex_string(),
    "11234567890abcd",
  )
  assert_eq!(
    wrapping_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 16).to_hex_string(),
    "11234567890ab",
  )
  assert_eq!(
    wrapping_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 32).to_hex_string(),
    "112345678",
  )
  assert_eq!(
    wrapping_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 64).to_hex_string(),
    "1",
  )
  assert_eq!(
    wrapping_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 128).to_hex_string(),
    "11234567890abcdef",
  )
  assert_eq!(
    op_shr({ high: 1, low: 0x1234_5678_90ab_cdef }, 128).to_hex_string(),
    "0",
  )
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

test {
  assert_eq!(
    mul64x64(2, 0xffff_ffff_ffff_ffffUL).to_hex_string(),
    "1fffffffffffffffe",
  )
}

/// count `1` bits in a UInt64. See [Bit Twiddling Hacks](http://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetParallel).
fn UInt128::popcnt64(u : UInt64) -> Int {
  let mut u_mut = u - ((u >> 1) & 0x5555555555555555)
  u_mut = (u_mut & 0x3333333333333333) + ((u_mut >> 2) & 0x3333333333333333)
  return ((((u_mut + (u_mut >> 4)) & 0xF0F0F0F0F0F0F0F) * 0x101010101010101) >>
  56).to_int()
}

/// count `1` bits in a UInt128
fn UInt128::popcnt(self : UInt128) -> Int {
  popcnt64(self.high) + popcnt64(self.low)
}

test {
  assert_eq!(mul64x64(2, 0xffff_ffff_ffff_ffffUL).popcnt(), 64)
}

fn u64_to_hex_string(input : UInt64) -> String {
  let hex_digits : FixedArray[String] = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let ret = FixedArray::make(16, "0")
  let mut mut_input = input
  for cnt = 15; cnt >= 0; cnt = cnt - 1 {
    ret[cnt] = hex_digits[(mut_input & 0xf).to_int()]
    mut_input = mut_input.lsr(4)
  }
  ret.fold_left(String::op_add, init="")
}

fn uint64_to_bytesle(input : UInt64) -> Bytes {
  let b = Bytes::new(8)
  b[0] = (input >> 56).to_byte()
  b[1] = (input >> 48).to_byte()
  b[2] = (input >> 40).to_byte()
  b[3] = (input >> 32).to_byte()
  b[4] = (input >> 24).to_byte()
  b[5] = (input >> 16).to_byte()
  b[6] = (input >> 8).to_byte()
  b[7] = input.to_byte()
  b
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

pub fn to_string(self : UInt128) -> String {
  if self == UInt128::zero() {
    return "0"
  }
  let mut self = self
  let s : Array[String] = []
  while self != { high: 0, low: 0 } {
    let d = self.div_rem(UInt128::from_uint(10U))
    self = d.0
    s.push(d.1.low.to_string())
  }
  s.fold_right(String::op_add, init="")
}

test {
  assert_eq!(
    UInt128::from_hex_string("ffffffffff123450ffffffffffffffff")
    .incf()
    .to_string(),
    UInt128::from_string("340282366920650986175549704880212934656").to_string(),
  )
}

pub fn output(self : UInt128, logger : Logger) -> Unit {
  let high = self.high
  let low = self.low
  logger.write_string("UInt128::{high:\{high}, low: \{low}}")
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

/// count trailing zero of a UInt64
fn trzcnt64(v : UInt64) -> Int {
  let mut v_mut = v
  let mut inv = v_mut.lnot()
  let mut carry = ((inv ^ (inv + 1)) & inv) >> 63
  inv = (v_mut & 0xffffffffUL) + 0xffffffffUL
  inv = ((inv & 0x100000000UL) ^ 0x100000000UL) >> 27
  carry += inv
  v_mut = v_mut >> inv.to_int()
  inv = (v_mut & 0xffffUL) + 0xffffUL
  inv = ((inv & 0x10000UL) ^ 0x10000UL) >> 12
  carry += inv
  v_mut = v_mut >> inv.to_int()
  inv = (v_mut & 0xffUL) + 0xffUL
  inv = ((inv & 0x100UL) ^ 0x100UL) >> 5
  carry += inv
  v_mut = v_mut >> inv.to_int()
  inv = (v_mut & 0xfUL) + 0xfUL
  inv = ((inv & 0x10UL) ^ 0x10UL) >> 2
  carry += inv
  v_mut = v_mut >> inv.to_int()
  inv = (v_mut & 3) + 3
  inv = ((inv & 4) ^ 4) >> 1
  carry += inv
  v_mut = v_mut >> inv.to_int()
  carry.to_int()
}

fn trzcnt(self : UInt128) -> Int {
  if self.low == 0 {
    trzcnt64(self.high) + 64
  } else {
    trzcnt64(self.low)
  }
}

test {
  assert_eq!(trzcnt64(16), 4)
  assert_eq!(trzcnt64(2_199_023_256_720), 4)
}

/// count leading zero of a UInt64
fn lezcnt64(v : UInt64) -> Int {
  let mut v_mut = v
  let mut inv = v_mut.lnot()
  let mut carry = ((inv ^ (inv + 1)) & inv) >> 63
  inv = (v_mut >> 32) + 0xffffffffUL
  inv = ((inv & 0x100000000UL) ^ 0x100000000UL) >> 27
  carry += inv
  v_mut = v_mut << inv.to_int()
  inv = (v_mut >> 48) + 0xffffUL
  inv = ((inv & 0x10000UL) ^ 0x10000UL) >> 12
  carry += inv
  v_mut = v_mut << inv.to_int()
  inv = (v_mut >> 56) + 0xffUL
  inv = ((inv & 0x100UL) ^ 0x100UL) >> 5
  carry += inv
  v_mut = v_mut << inv.to_int()
  inv = (v_mut >> 60) + 0xfUL
  inv = ((inv & 0x10UL) ^ 0x10UL) >> 2
  carry += inv
  v_mut = v_mut << inv.to_int()
  inv = (v_mut >> 62) + 3
  inv = ((inv & 4) ^ 4) >> 1
  carry += inv
  v_mut = v_mut << inv.to_int()
  carry += (v_mut >> 63) ^ 1
  carry.to_int()
}

fn lezcnt(self : UInt128) -> Int {
  if self.high == 0 {
    lezcnt64(self.low) + 64
  } else {
    lezcnt64(self.high)
  }
}

test {
  assert_eq!(lezcnt64(25UL), 59) // 25 = 1_1001
  assert_eq!(lezcnt64(67UL << lezcnt64(67UL)), 0)
}

test {
  assert_eq!(
    ({ high: 0xffff_ffff_ffff_ffffUL, low: 0 } / { high: 0, low: 2 }).to_hex_string(),
    "7fffffffffffffff8000000000000000",
  )
  assert_eq!(
    ({ high: 0xffff_ffff_ffff_ffffUL, low: 0 } /
    { high: 0xffff_ffff_ffff_ffffUL, low: 0 }).to_hex_string(),
    "1",
  )
  let d = UInt128::max() / UInt128::make(1UL, 3UL)
  let m = UInt128::max() % UInt128::make(1UL, 3UL)
  assert_eq!(d * UInt128::make(1UL, 3UL) + m, UInt128::max())
  assert_eq!(
    (UInt128::make(0xffff_1293_8fff_1234UL, 0x4321_abcd_ef01_2530UL) /
    UInt128::from_uint(16)).to_hex_string(),
    "ffff12938fff12344321abcdef01253",
  )
}

pub fn op_div(self : UInt128, other : UInt128) -> UInt128 {
  div128by128(self, other).0
}

pub fn op_mod(self : UInt128, other : UInt128) -> UInt128 {
  div128by128(self, other).1
}

/// returns `(quotient,remainder)`
fn div_rem64(u : UInt64, v : UInt64) -> (UInt64, UInt64) {
  let q = u / v
  return (q, u - q * v)
}

fn div_rem(self : UInt128, other : UInt128) -> (UInt128, UInt128) {
  div128by128(self, other)
}

/// divide-and-conquer
fn div128by128(u : UInt128, v : UInt128) -> (UInt128, UInt128) {
  let mut rem = UInt128::zero()
  let quo = UInt128::zero()
  if v.high == 0UL { // denominator <= 64 bits
    rem.high = 0UL
    if u.high == 0UL { // numerator <= 64 bits, use native div
      if u.low < v.low {
        quo.low = 0UL
        rem.low = u.low
      } else {
        let d = div_rem64(u.low, v.low)
        quo.low = d.0
        rem.low = d.1
      }
    } else {
      let d = div_rem64(u.high, v.low)
      quo.high = d.0
      let qr = div128by64(d.1, u.low, v.low)
      quo.low = qr.0
      rem.low = qr.1
    }
  } else {
    quo.high = 0UL
    if u.high < v.high || (u.high == v.high && u.low <= v.low) {
      quo.low = (u.high == v.high).to_int64().to_uint64()
      rem.high = u.high
      rem.low = u.low
      return (quo, rem)
    }
    let shift = lezcnt64(v.high)
    let quo_t : UInt64 = div128bynorm64(
        u.high >> 1,
        (u.high << 63) | (u.low >> 1),
        if shift == 0 {
          v.high
        } else {
          (v.high << shift) | (v.low >> (64 - shift))
        },
      ).0
    quo.low = quo_t >> (63 - shift)
    // handle edge
    quo.low -= 1
    rem = { ..quo, high: 0 } * v
    rem = u - rem
    if rem.high > v.high || (rem.high == v.high && rem.low >= v.low) {
      quo.low += 1
      rem -= v
    }
  }
  (quo, rem)
}

fn div128by64(
  u_high : UInt64,
  u_low : UInt64,
  v_low : UInt64
) -> (UInt64, UInt64) {
  let s = lezcnt64(v_low)
  let mut u_high = u_high
  let mut u_low = u_low
  let mut v_low = v_low
  if s != 0 {
    u_high = (u_high << s) | (u_low >> (64 - s))
    u_low = u_low << s
    v_low = v_low << s
  }
  let d = div128bynorm64(u_high, u_low, v_low)
  let q = d.0
  let mut r = d.1
  r = r >> s
  (q, r)
}

fn div128bynorm64(
  u_high : UInt64,
  u_low : UInt64,
  v_low : UInt64
) -> (UInt64, UInt64) {
  let u_low_0 = u_low & 0xffffffff
  let u_low_1 = u_low >> 32
  let v_low_0 = v_low & 0xffffffff
  let v_low_1 = v_low >> 32
  let mut q_low_1 = u_high / v_low_1
  if (q_low_1 >> 32) != 0UL {
    q_low_1 = 0xffffffffUL
  }
  let mut rhat = u_high - q_low_1 * v_low_1
  while q_low_1 * v_low_0 > ((rhat << 32) | u_low_1) {
    q_low_1 -= 1
    rhat += v_low_1
    if (rhat >> 32) != 0UL {
      break
    }
  }
  let mut r = ((u_high << 32) | u_low_1) - q_low_1 * v_low
  let mut q_low_0 = r / v_low_1
  if (q_low_0 >> 32) != 0UL {
    q_low_0 = 0xffffffffUL
  }
  rhat = r - q_low_0 * v_low_1
  while q_low_0 * v_low_0 > ((rhat << 32) | u_low_0) {
    q_low_0 -= 1
    rhat += v_low_1
    if (rhat >> 32) != 0UL {
      break
    }
  }
  r = ((r << 32) | u_low_0) - q_low_0 * v_low
  return ((q_low_1 << 32) | q_low_0, r)
}

enum ParseRadix {
  Bin
  Oct
  Dec
}

fn try_parse(s : String, ~radix : ParseRadix = Dec) -> UInt128!Failure {
  let r = match radix {
    Bin => 2
    Oct => 8
    Dec => 10
  }
  if s.is_empty() {
    fail!("empty string")
  } else {
    let s = s.trim_space()
    if s.is_empty() {
      return fail!("blank string")
    } else {
      let mut s = s
      if s[0] == '+' {
        s = s.substring(start=1)
      }
      let mut v = UInt128::zero()
      for c in s {
        let cs = c.to_int() - '0'.to_int()
        let prev = v.copy()
        if cs >= 0 && cs < r {
          v = prev * { high: 0, low: r.to_int64().to_uint64() } +
            { high: 0, low: cs.to_int64().to_uint64() }
        } else {
          return fail!("trash inside string: \{c}")
        }
      }
      v
    }
  }
}

fn try_parse16(s : String) -> UInt128!Failure {
  if s.is_empty() {
    fail!("empty string")
  } else {
    let s = s.trim_space()
    if s.is_empty() {
      return fail!("blank string")
    } else {
      let mut s = s.to_lower()
      if s[0] == '+' {
        s = s.substring(start=1)
      }
      let mut v = UInt128::zero()
      for c in s {
        let prev = v.copy()
        if c >= '0' && c <= '9' {
          let cs = c.to_int() - '0'.to_int()
          v = prev * { high: 0, low: 16UL } +
            { high: 0, low: cs.to_int64().to_uint64() }
        } else if c >= 'a' && c <= 'f' {
          let cs = c.to_int() - 87
          v = prev * { high: 0, low: 16UL } +
            { high: 0, low: cs.to_int64().to_uint64() }
        } else {
          return fail!("trash inside string: \{c}")
        }
      }
      v
    }
  }
}

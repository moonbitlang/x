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

// An AES block-cipher implementation based on
// [FIPS 197] https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf

///|
/// Errors raised by AES operations on invalid key, block, IV or data lengths.
pub suberror CryptoError {
  InvalidCrypto(msg~ : String)
}

///|
/// An expanded AES key schedule, shared by the ECB/CBC mode functions. No
/// padding is applied anywhere; callers must pad themselves.
priv struct AesSchedule {
  round_keys : FixedArray[UInt]
  rounds : Int
}

///|
/// Multiplies two bytes in GF(2^8) without secret-dependent branches.
fn gf_mul(a : Int, b : Int) -> Int {
  let mut x = a & 0xff
  let mut y = b & 0xff
  let mut res = 0
  for _ in 0..<=7 {
    let y_mask = 0 - (y & 1)
    res = res ^ (x & y_mask)
    let high_bit_mask = 0 - ((x >> 7) & 1)
    x = ((x << 1) & 0xff) ^ (0x1b & high_bit_mask)
    y = y >> 1
  }
  res & 0xff
}

///|
fn gf_pow(x : Int, exp : Int) -> Int {
  let mut result = 1
  let mut base = x & 0xff
  let mut e = exp
  while e > 0 {
    if (e & 1) != 0 {
      result = gf_mul(result, base)
    }
    base = gf_mul(base, base)
    e = e >> 1
  }
  result & 0xff
}

///|
fn rotl8(x : Int, bits : Int) -> Int {
  ((x << bits) | (x >> (8 - bits))) & 0xff
}

///|
fn aes_sub_byte(value : Byte) -> Byte {
  let inv = gf_pow(value.to_int(), 254)
  (inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63).to_byte()
}

///|
fn aes_inv_sub_byte(value : Byte) -> Byte {
  let x = value.to_int()
  let inverse_affine = rotl8(x, 1) ^ rotl8(x, 3) ^ rotl8(x, 6) ^ 0x05
  gf_pow(inverse_affine, 254).to_byte()
}

///|
fn aes_rcon() -> Array[UInt] {
  let rcon : Array[UInt] = []
  let mut value = 1
  for _ in 0..<=13 {
    rcon.push(value.reinterpret_as_uint() << 24)
    value = gf_mul(value, 2)
  }
  rcon
}

///|
fn u32_from_be(bytes : BytesView, offset : Int) -> UInt {
  let b0 = bytes[offset].to_uint()
  let b1 = bytes[offset + 1].to_uint()
  let b2 = bytes[offset + 2].to_uint()
  let b3 = bytes[offset + 3].to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn aes_sub_word(word : UInt) -> UInt {
  let b0 = aes_sub_byte((word >> 24).to_byte()).to_uint()
  let b1 = aes_sub_byte((word >> 16).to_byte()).to_uint()
  let b2 = aes_sub_byte((word >> 8).to_byte()).to_uint()
  let b3 = aes_sub_byte(word.to_byte()).to_uint()
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn aes_rot_word(word : UInt) -> UInt {
  (word << 8) | (word >> 24)
}

///|
let aes_rcon_cached : Array[UInt] = aes_rcon()

///|
fn aes_schedule(key : BytesView) -> AesSchedule raise CryptoError {
  let key_len = key.length()
  guard key_len == 16 || key_len == 24 || key_len == 32 else {
    raise InvalidCrypto(msg="invalid AES key size")
  }
  let nk = key_len / 4
  let rounds = nk + 6
  let total_words = 4 * (rounds + 1)
  let w : FixedArray[UInt] = FixedArray::make(total_words, 0U)
  for i in 0..<nk {
    w[i] = u32_from_be(key, i * 4)
  }
  let rcon = aes_rcon_cached
  for i in nk..<total_words {
    let mut temp = w[i - 1]
    if i % nk == 0 {
      temp = aes_sub_word(aes_rot_word(temp)) ^ rcon[i / nk - 1]
    } else if nk > 6 && i % nk == 4 {
      temp = aes_sub_word(temp)
    }
    w[i] = w[i - nk] ^ temp
  }
  { round_keys: w, rounds }
}

///|
fn byte_xor(a : Byte, b : Byte) -> Byte {
  (a.to_int() ^ b.to_int()).to_byte()
}

///|
fn aes_add_round_key(
  state : Array[Byte],
  round_keys : FixedArray[UInt],
  round : Int,
) -> Unit {
  let base = round * 4
  for word_index in 0..<4 {
    let word = round_keys[base + word_index]
    let offset = word_index * 4
    state[offset] = byte_xor(state[offset], (word >> 24).to_byte())
    state[offset + 1] = byte_xor(state[offset + 1], (word >> 16).to_byte())
    state[offset + 2] = byte_xor(state[offset + 2], (word >> 8).to_byte())
    state[offset + 3] = byte_xor(state[offset + 3], word.to_byte())
  }
}

///|
fn aes_sub_bytes(state : Array[Byte]) -> Unit {
  for i in 0..<=15 {
    state[i] = aes_sub_byte(state[i])
  }
}

///|
fn aes_inv_sub_bytes(state : Array[Byte]) -> Unit {
  for i in 0..<=15 {
    state[i] = aes_inv_sub_byte(state[i])
  }
}

///|
fn aes_shift_rows(state : Array[Byte]) -> Unit {
  let row_1 = state[1]
  state[1] = state[5]
  state[5] = state[9]
  state[9] = state[13]
  state[13] = row_1
  let row_2_a = state[2]
  let row_2_b = state[6]
  state[2] = state[10]
  state[6] = state[14]
  state[10] = row_2_a
  state[14] = row_2_b
  let row_3 = state[3]
  state[3] = state[15]
  state[15] = state[11]
  state[11] = state[7]
  state[7] = row_3
}

///|
fn aes_inv_shift_rows(state : Array[Byte]) -> Unit {
  let row_1 = state[13]
  state[13] = state[9]
  state[9] = state[5]
  state[5] = state[1]
  state[1] = row_1
  let row_2_a = state[2]
  let row_2_b = state[6]
  state[2] = state[10]
  state[6] = state[14]
  state[10] = row_2_a
  state[14] = row_2_b
  let row_3 = state[3]
  state[3] = state[7]
  state[7] = state[11]
  state[11] = state[15]
  state[15] = row_3
}

///|
fn aes_mix_columns(state : Array[Byte]) -> Unit {
  for column in 0..<4 {
    let offset = column * 4
    let s0 = state[offset].to_int()
    let s1 = state[offset + 1].to_int()
    let s2 = state[offset + 2].to_int()
    let s3 = state[offset + 3].to_int()
    state[offset] = (gf_mul(s0, 2) ^ gf_mul(s1, 3) ^ s2 ^ s3).to_byte()
    state[offset + 1] = (s0 ^ gf_mul(s1, 2) ^ gf_mul(s2, 3) ^ s3).to_byte()
    state[offset + 2] = (s0 ^ s1 ^ gf_mul(s2, 2) ^ gf_mul(s3, 3)).to_byte()
    state[offset + 3] = (gf_mul(s0, 3) ^ s1 ^ s2 ^ gf_mul(s3, 2)).to_byte()
  }
}

///|
fn aes_inv_mix_columns(state : Array[Byte]) -> Unit {
  for column in 0..<4 {
    let offset = column * 4
    let s0 = state[offset].to_int()
    let s1 = state[offset + 1].to_int()
    let s2 = state[offset + 2].to_int()
    let s3 = state[offset + 3].to_int()
    state[offset] = (gf_mul(s0, 14) ^
    gf_mul(s1, 11) ^
    gf_mul(s2, 13) ^
    gf_mul(s3, 9)).to_byte()
    state[offset + 1] = (gf_mul(s0, 9) ^
    gf_mul(s1, 14) ^
    gf_mul(s2, 11) ^
    gf_mul(s3, 13)).to_byte()
    state[offset + 2] = (gf_mul(s0, 13) ^
    gf_mul(s1, 9) ^
    gf_mul(s2, 14) ^
    gf_mul(s3, 11)).to_byte()
    state[offset + 3] = (gf_mul(s0, 11) ^
    gf_mul(s1, 13) ^
    gf_mul(s2, 9) ^
    gf_mul(s3, 14)).to_byte()
  }
}

///|
fn aes_encrypt_state(schedule : AesSchedule, state : Array[Byte]) -> Unit {
  aes_add_round_key(state, schedule.round_keys, 0)
  for round in 1..<schedule.rounds {
    aes_sub_bytes(state)
    aes_shift_rows(state)
    aes_mix_columns(state)
    aes_add_round_key(state, schedule.round_keys, round)
  }
  aes_sub_bytes(state)
  aes_shift_rows(state)
  aes_add_round_key(state, schedule.round_keys, schedule.rounds)
}

///|
fn aes_decrypt_state(schedule : AesSchedule, state : Array[Byte]) -> Unit {
  aes_add_round_key(state, schedule.round_keys, schedule.rounds)
  for round = schedule.rounds - 1; round > 0; round = round - 1 {
    aes_inv_shift_rows(state)
    aes_inv_sub_bytes(state)
    aes_add_round_key(state, schedule.round_keys, round)
    aes_inv_mix_columns(state)
  }
  aes_inv_shift_rows(state)
  aes_inv_sub_bytes(state)
  aes_add_round_key(state, schedule.round_keys, 0)
}

///|
/// Encrypts a 16-byte `state` in place (used by the CBC mode for chaining,
/// where the caller XORs before encrypting, without an intermediate copy).
///
/// Raises `CryptoError` if `state` is not exactly 16 bytes long.
fn AesSchedule::encrypt_block_in_place(
  self : AesSchedule,
  state : Array[Byte],
) -> Unit raise CryptoError {
  guard state.length() == 16 else {
    raise InvalidCrypto(msg="invalid AES block size")
  }
  aes_encrypt_state(self, state)
}

///|
/// Decrypts a 16-byte `state` in place (used by the CBC mode for chaining,
/// where the caller XORs after decrypting, without an intermediate copy).
///
/// Raises `CryptoError` if `state` is not exactly 16 bytes long.
fn AesSchedule::decrypt_block_in_place(
  self : AesSchedule,
  state : Array[Byte],
) -> Unit raise CryptoError {
  guard state.length() == 16 else {
    raise InvalidCrypto(msg="invalid AES block size")
  }
  aes_decrypt_state(self, state)
}

///|
/// Encrypts `data` (a multiple of 16 bytes) with AES in ECB mode.
/// No padding is applied; callers must pad themselves.
///
/// Raises `CryptoError` if `key` or `data` has an invalid length.
pub fn aes_ecb_encrypt(
  key : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  let data_length = data.length()
  guard data_length % 16 == 0 else {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data_length)
  let state = Array::make(16, Byte::default())
  let mut offset = 0
  while offset < data_length {
    for i in 0..<=15 {
      state[i] = data[offset + i]
    }
    schedule.encrypt_block_in_place(state)
    out.append(state)
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
/// Decrypts `data` (a multiple of 16 bytes) with AES in ECB mode.
///
/// Raises `CryptoError` if `key` or `data` has an invalid length.
pub fn aes_ecb_decrypt(
  key : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  let data_length = data.length()
  guard data_length % 16 == 0 else {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data_length)
  let state = Array::make(16, Byte::default())
  let mut offset = 0
  while offset < data_length {
    for i in 0..<=15 {
      state[i] = data[offset + i]
    }
    schedule.decrypt_block_in_place(state)
    out.append(state)
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
/// Encrypts `data` (a multiple of 16 bytes) with AES in CBC mode.
/// No padding is applied; callers must pad themselves.
///
/// Raises `CryptoError` if `key`, `iv` or `data` has an invalid length.
pub fn aes_cbc_encrypt(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  guard iv.length() == 16 else {
    raise InvalidCrypto(msg="invalid AES IV length")
  }
  let data_length = data.length()
  guard data_length % 16 == 0 else {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data_length)
  let prev = iv.to_array()
  let state = Array::make(16, Byte::default())
  let mut offset = 0
  while offset < data_length {
    for i in 0..<=15 {
      state[i] = byte_xor(data[offset + i], prev[i])
    }
    schedule.encrypt_block_in_place(state)
    out.append(state)
    for i in 0..<=15 {
      prev[i] = state[i]
    }
    offset = offset + 16
  }
  Bytes::from_array(out)
}

///|
/// Decrypts `data` (a multiple of 16 bytes) with AES in CBC mode.
///
/// Raises `CryptoError` if `key`, `iv` or `data` has an invalid length.
pub fn aes_cbc_decrypt(
  key : BytesView,
  iv : BytesView,
  data : BytesView,
) -> Bytes raise CryptoError {
  guard iv.length() == 16 else {
    raise InvalidCrypto(msg="invalid AES IV length")
  }
  let data_length = data.length()
  guard data_length % 16 == 0 else {
    raise InvalidCrypto(msg="invalid AES data length")
  }
  let schedule = aes_schedule(key)
  let out : Array[Byte] = Array::new(capacity=data_length)
  let prev = iv.to_array()
  let state = Array::make(16, Byte::default())
  let mut offset = 0
  while offset < data_length {
    for i in 0..<=15 {
      state[i] = data[offset + i]
    }
    schedule.decrypt_block_in_place(state)
    for i in 0..<=15 {
      state[i] = byte_xor(state[i], prev[i])
      prev[i] = data[offset + i]
    }
    out.append(state)
    offset = offset + 16
  }
  Bytes::from_array(out)
}

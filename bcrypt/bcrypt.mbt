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
let magic_cipher_data : Bytes = b"OrpheanBeholderScryDoubt"

///|
fn bcrypt_hash_raw(password : BytesView, salt : BytesView, cost : Int) -> Bytes {
  let key = bcrypt_key(password)
  let state = new_blowfish_state()
  blowfish_expand_key(state, salt, key.view())
  let rounds : UInt = 1U << cost
  for _ in 0U..<rounds {
    blowfish_expand_zero_key(state, key.view())
    blowfish_expand_zero_key(state, salt)
  }

  let cdata = Array(capacity=6)
  let mut off = 0
  for _ in 0..<6 {
    let (word, next_off) = stream_to_word(magic_cipher_data.view(), off)
    cdata.push(word)
    off = next_off
  }
  for _ in 0..<64 {
    for j in 0..<3 {
      let (l, r) = blowfish_encrypt_block(state, cdata[j * 2], cdata[j * 2 + 1])
      cdata[j * 2] = l
      cdata[j * 2 + 1] = r
    }
  }

  let out = Array(capacity=24)
  for i in 0..<6 {
    out.push((cdata[i] >> 24).to_byte())
    out.push((cdata[i] >> 16).to_byte())
    out.push((cdata[i] >> 8).to_byte())
    out.push(cdata[i].to_byte())
  }
  Bytes::from_array(out.view())
}

///|
fn bcrypt_key(password : BytesView) -> Bytes {
  let n = if password.length() > 72 { 72 } else { password.length() }
  Bytes::makei(n + 1, fn(i) { if i < n { password[i] } else { (0).to_byte() } })
}

///|
pub let min_cost = 4

///|
pub let max_cost = 31

///|
pub let salt_length = 16

///|
pub let hash_length = 60

///|
pub suberror BcryptError {
  InvalidCost(Int)
  InvalidSaltLength(Int)
  InvalidHashFormat
  UnsupportedVersion(String)
  InvalidBase64
} derive(Eq, Debug)

///|
pub impl Show for BcryptError with fn output(self, logger) {
  match self {
    InvalidCost(n) => {
      logger.write_string("InvalidCost(")
      logger.write_object(n)
      logger.write_string(")")
    }
    InvalidSaltLength(n) => {
      logger.write_string("InvalidSaltLength(")
      logger.write_object(n)
      logger.write_string(")")
    }
    InvalidHashFormat => logger.write_string("InvalidHashFormat")
    UnsupportedVersion(v) => {
      logger.write_string("UnsupportedVersion(")
      logger.write_string(v)
      logger.write_string(")")
    }
    InvalidBase64 => logger.write_string("InvalidBase64")
  }
}

///|
priv struct ParsedHash {
  minor : Char
  cost : Int
  salt_text : String
  salt : Bytes
}

///|
pub fn hash_password(
  password : Bytes,
  salt : Bytes,
  cost : Int,
) -> Result[String, BcryptError] {
  if cost < min_cost || cost > max_cost {
    Err(InvalidCost(cost))
  } else if salt.length() != salt_length {
    Err(InvalidSaltLength(salt.length()))
  } else {
    let salt_text = bcrypt_base64_encode(salt.view(), salt_length)
    let digest = bcrypt_hash_raw(password.view(), salt.view(), cost)
    let hash_text = bcrypt_base64_encode(digest.view(), 23)
    Ok("$2b$" + two_digit(cost) + "$" + salt_text + hash_text)
  }
}

///|
pub fn verify(password : Bytes, hash : String) -> Result[Bool, BcryptError] {
  match parse_hash(hash) {
    Err(err) => Err(err)
    Ok(parsed) => {
      let digest = bcrypt_hash_raw(
        password.view(),
        parsed.salt.view(),
        parsed.cost,
      )
      let recomputed = "$2" +
        parsed.minor.to_string() +
        "$" +
        two_digit(parsed.cost) +
        "$" +
        parsed.salt_text +
        bcrypt_base64_encode(digest.view(), 23)
      Ok(timing_safe_equal(hash, recomputed))
    }
  }
}

///|
pub fn cost(hash : String) -> Result[Int, BcryptError] {
  match parse_hash(hash) {
    Err(err) => Err(err)
    Ok(parsed) => Ok(parsed.cost)
  }
}

///|
fn parse_hash(hash : String) -> Result[ParsedHash, BcryptError] {
  if hash.length() != hash_length {
    Err(InvalidHashFormat)
  } else if hash[0].to_int() != '$'.to_int() ||
    hash[1].to_int() != '2'.to_int() ||
    hash[3].to_int() != '$'.to_int() ||
    hash[6].to_int() != '$'.to_int() {
    Err(InvalidHashFormat)
  } else {
    let minor = hash.get_char(2).unwrap()
    if minor != 'b' && minor != 'y' {
      Err(UnsupportedVersion("2" + minor.to_string()))
    } else if !is_ascii_digit_code(hash[4].to_int()) ||
      !is_ascii_digit_code(hash[5].to_int()) {
      Err(InvalidHashFormat)
    } else {
      let parsed_cost = (hash[4].to_int() - '0'.to_int()) * 10 +
        (hash[5].to_int() - '0'.to_int())
      if parsed_cost < min_cost || parsed_cost > max_cost {
        Err(InvalidCost(parsed_cost))
      } else {
        let salt_text = hash.unsafe_substring(start=7, end=29)
        match bcrypt_base64_decode(salt_text, salt_length) {
          Err(_) => Err(InvalidBase64)
          Ok(salt) =>
            if !bcrypt_base64_all_valid(hash.unsafe_substring(start=29, end=60)) {
              Err(InvalidBase64)
            } else {
              Ok({ minor, cost: parsed_cost, salt_text, salt })
            }
        }
      }
    }
  }
}

///|
fn two_digit(n : Int) -> String {
  let tens = n / 10 + '0'.to_int()
  let ones = n % 10 + '0'.to_int()
  String::from_array([tens.unsafe_to_char(), ones.unsafe_to_char()])
}

///|
fn is_ascii_digit_code(code : Int) -> Bool {
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn timing_safe_equal(a : String, b : String) -> Bool {
  let mut diff = a.length() ^ b.length()
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    diff = diff | (a[i].to_int() ^ b[i].to_int())
  }
  diff == 0
}

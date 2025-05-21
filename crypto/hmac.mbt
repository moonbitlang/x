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
/// Computes HMAC (Hash-based Message Authentication Code) using a specified
/// cryptographic hash function.
///
/// Parameters:
///
/// * `hash` : A hash function implementation that satisfies the `CryptoHasher`
/// trait.
/// * `key` : The secret key used for generating the authentication code.
/// * `message` : The message to be authenticated.
///
/// Returns a fixed-size array of bytes containing the HMAC value. The length of
/// the output depends on the underlying hash function's output size.
///
pub fn[H : CryptoHasher] hmac(
  hash : H,
  key : FixedArray[Byte],
  message : FixedArray[Byte],
) -> FixedArray[Byte] {
  let block_size = hash.block_size()
  let working_key = if key.length() > block_size {
    // if key is longer than block size, hash it
    hash.reset()
    hash.update(key)
    hash.finalize()
  } else {
    key
  }
  let padded_key = if working_key.length() < block_size {
    // if key is shorter than block size, pad it with zeros
    let padded = FixedArray::make(block_size, b'\x00')
    working_key.blit_to(padded, len=working_key.length())
    padded
  } else {
    working_key
  }
  // create inner and outer padding arrays
  let ipad = FixedArray::make(block_size, b'\x36')
  let opad = FixedArray::make(block_size, b'\x5c')
  // calculate inner hash
  let inner_key = xor_bytes(padded_key, ipad)
  hash.reset()
  hash.update(inner_key)
  hash.update(message)
  let inner_hash = hash.finalize()
  // calculate outer hash
  let outer_key = xor_bytes(padded_key, opad)
  hash.reset()
  hash.update(outer_key)
  hash.update(inner_hash)
  hash.finalize()
}

///|
fn xor_bytes(a : FixedArray[Byte], b : FixedArray[Byte]) -> FixedArray[Byte] {
  let result = FixedArray::make(a.length(), b'\x00')
  for i = 0; i < a.length(); i = i + 1 {
    result[i] = a[i] ^ b[i]
  }
  result
}

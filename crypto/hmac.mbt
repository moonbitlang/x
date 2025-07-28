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
  key : @bytes.View,
  message : @bytes.View,
) -> FixedArray[Byte] {
  let block_size = hash.block_size()
  let padded_key = FixedArray::make(block_size, b'\x00')
  if key.length() > block_size {
    // if key is longer than block size, hash it
    let working_key = hash..reset()..update(key).finalize()
    working_key.blit_to(padded_key, len=working_key.length())
    working_key.fill(0)
  } else {
    padded_key.blit_from_bytesview(0, key)
  }
  // calculate inner hash
  for i = 0; i < block_size; i = i + 1 {
    padded_key[i] = padded_key[i] ^ b'\x36'
  }
  let inner_hash = hash
    ..reset()
    ..update(padded_key.unsafe_reinterpret_as_bytes())
    ..update(message)
    .finalize()
  // calculate outer hash
  for i = 0; i < block_size; i = i + 1 {
    padded_key[i] = padded_key[i] ^ b'\x36' ^ b'\x5c'
  }
  let result = hash
    ..reset()
    ..update(padded_key.unsafe_reinterpret_as_bytes())
    ..update(inner_hash.unsafe_reinterpret_as_bytes())
    .finalize()
  // clear sensitive data
  padded_key.fill(0)
  inner_hash.fill(0)
  result
}

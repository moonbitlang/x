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
test "bcrypt base64 round trip" {
  let salt = Bytes::from_array([
    (0x71).to_byte(),
    (0xd7).to_byte(),
    (0x9f).to_byte(),
    (0x82).to_byte(),
    (0x18).to_byte(),
    (0xa3).to_byte(),
    (0x92).to_byte(),
    (0x59).to_byte(),
    (0xa7).to_byte(),
    (0xa2).to_byte(),
    (0x9a).to_byte(),
    (0xab).to_byte(),
    (0xb2).to_byte(),
    (0xdb).to_byte(),
    (0xaf).to_byte(),
    (0xc3).to_byte(),
  ])
  let encoded = bcrypt_base64_encode(salt.view(), 16)
  assert_eq(encoded, "abcdefghijklmnopqrstuu")
  assert_eq(bcrypt_base64_decode(encoded, 16).unwrap(), salt)
  assert_eq(
    bcrypt_base64_decode("......................", 16).unwrap(),
    Bytes::make(16, (0).to_byte()),
  )
}

///|
test "stream_to_word wraps input" {
  let (word, offset) = stream_to_word(b"abc".view(), 0)
  assert_eq(word, 0x61626361U)
  assert_eq(offset, 1)
}

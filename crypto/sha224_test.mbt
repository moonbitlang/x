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
test "sha224-additional" {
  @test.assert_eq(
    sha224test(""),
    "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f",
  )
  @test.assert_eq(
    sha224test("a"),
    "3118199937a95dd0dd06a74ac0bf1517e958f08ae87ef9d7e89f139a",
  )
  @test.assert_eq(
    sha224test("message digest"),
    "dcf41f0075ccc16b44cc9f6d1900a34bbc2841893eaf4bf2f64edf95",
  )
  @test.assert_eq(
    sha224test("abcdefghijklmnopqrstuvwxyz"),
    "1c3ace1531530751e862592a3fe33e682d7e36c2f9df58a384eb49bd",
  )
  @test.assert_eq(
    sha224test("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"),
    "eefa179ecbcba0011f77a6ff43815e8b3a92932456b373ed69b639cb",
  )
  @test.assert_eq(
    sha224test(
      "12345678901234567890123456789012345678901234567890123456789012345678901234567890",
    ),
    "5d0b10a347de663745ae351d996e7d830daaa06379992a6017c9c99e",
  )
  @test.assert_eq(
    sha224test(
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
    ),
    "f029eeb25a211521aeb144cb1b9ad38d2313a8312d13599ca6a8f39a",
  )
}

///|
test "sha224 streaming" {
  let ctx = SHA224::new()
  ctx.update(b"abc")
  @test.assert_eq(
    bytes_to_hex_string(ctx.finalize()),
    "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
  )
  let chunked = SHA224::new()
  chunked.update(b"a")
  chunked.update(b"b")
  chunked.update(b"c")
  @test.assert_eq(
    bytes_to_hex_string(chunked.finalize()),
    bytes_to_hex_string(sha224(b"abc")),
  )
  let iter = SHA224::new()
  iter.update_from_iter(b"abc".iter())
  @test.assert_eq(
    bytes_to_hex_string(iter.finalize()),
    bytes_to_hex_string(sha224(b"abc")),
  )
}

///|
test "sha224 reset" {
  let ctx = SHA224::new()
  ctx.update(b"abc")
  let first = bytes_to_hex_string(ctx.finalize())
  ctx.update(b"abc")
  ctx.reset()
  ctx.update(b"abc")
  @test.assert_eq(bytes_to_hex_string(ctx.finalize()), first)
}

///|
test "sha224 finalize_into" {
  let ctx = SHA224::new()
  ctx.update(b"abc")
  let digest = ctx.finalize()
  let buffer = FixedArray::make(32, b'\x00')
  ctx.finalize_into(buffer, offset=4)
  for i = 0; i < 28; i = i + 1 {
    @test.assert_eq(buffer[i + 4], digest[i])
  }
  @test.assert_eq(buffer[0], b'\x00')
  @test.assert_eq(buffer[31], digest[27])
}

///|
test "sha224 hmac" {
  let key = FixedArray::make(20, b'\x0b').unsafe_reinterpret_as_bytes()
  let message = b"Hi There"
  @test.assert_eq(
    bytes_to_hex_string(hmac(SHA224::new(), key, message)),
    "896fb1128abbdf196832107cd49df33f47b4b1169912ba4f53684b22",
  )
}

///|
#warnings("-deprecated")
test "sha224 via deprecated initial state" {
  let ctx = SHA256::new(reg=[
    0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7,
    0xbefa4fa4,
  ])
  ctx.update(b"abc")
  let expected = sha224(b"abc")
  let full = ctx.finalize()
  @test.assert_eq(full.length(), 32)
  for i = 0; i < 28; i = i + 1 {
    @test.assert_eq(full[i], expected[i])
  }
}

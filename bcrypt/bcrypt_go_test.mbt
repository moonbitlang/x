// Adapted from Go's TestInvalidHashErrors, TestCost, and TestTooLongPasswordsWork.
// Source: https://github.com/golang/crypto/blob/master/bcrypt/bcrypt_test.go
//
// Version adaptation: this package emits $2b$ and accepts $2b$/$2y$.
// The 57-byte ASCII vector's expected prefix changes from $2a$ to $2b$;
// its password, salt, cost, and digest are unchanged. This input does not
// trigger historical length-wraparound or high-bit-byte differences.
// This does not imply that arbitrary $2a$ hashes can be relabeled as $2b$.
//
// Copyright 2011 The Go Authors. All rights reserved.
// Copyright 2009 The Go Authors.
//
// BSD-3-Clause license: https://github.com/golang/crypto/blob/master/LICENSE
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google LLC nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

///|
test "Go invalid hash errors" {
  // Use the supported 2b minor version so each case reaches the intended error.
  // Go's short-hash, new-major, and bad-prefix errors map to InvalidHashFormat.
  let invalid_hashes = [
    "$2b$10$fooo", "$2b", "$3b$10$sssssssssssssssssssssshhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
    "%2b$10$sssssssssssssssssssssshhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh",
  ]
  for hash in invalid_hashes {
    assert_true(@bcrypt.cost(hash) is Err(@bcrypt.InvalidHashFormat), msg=hash)
    assert_true(
      @bcrypt.verify(b"anything", hash) is Err(@bcrypt.InvalidHashFormat),
      msg=hash,
    )
  }
  let invalid_cost = "$2b$32$sssssssssssssssssssssshhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh"
  assert_true(@bcrypt.cost(invalid_cost) is Err(@bcrypt.InvalidCost(32)))
  assert_true(
    @bcrypt.verify(b"anything", invalid_cost) is Err(@bcrypt.InvalidCost(32)),
  )
}

///|
test "Go cost extraction" {
  let suffix = "XajjQvNhvvRt5GSeFk1xFe5l47dONXg781AmZtd869sO8zfsHuw7C"
  // This API supports 2b and 2y, replacing Go's 2a and version without a minor.
  // Cost 31 is parsed only; computing its hash is unsuitable for a routine test.
  for version in ["2b", "2y"] {
    for case in [("04", 4), ("10", 10), ("31", 31)] {
      let (cost_text, expected) = case
      let hash = "$\{version}$\{cost_text}$\{suffix}"
      assert_eq(@bcrypt.cost(hash), Ok(expected), msg=hash)
    }
  }
  assert_true(@bcrypt.cost("$a$a$" + suffix) is Err(@bcrypt.InvalidHashFormat))
}

///|
test "Go password beyond the Blowfish 56 byte limit" {
  let password = b"012345678901234567890123456789012345678901234567890123456"
  // Decoded form of Go's salt XajjQvNhvvRt5GSeFk1xFe.
  let salt : Bytes = [
    0x65, 0xc9, 0x65, 0x4b, 0x13, 0xe3, 0xc7, 0x14, 0xef, 0xec, 0x85, 0x20, 0x1e,
    0x6d, 0xf3, 0x1e,
  ]
  let expected = "$2b$10$XajjQvNhvvRt5GSeFk1xFe5l47dONXg781AmZtd869sO8zfsHuw7C"
  assert_eq(password.length(), 57)
  assert_eq(@bcrypt.hash_password(password, salt, 10), Ok(expected))
  assert_eq(@bcrypt.verify(password, expected), Ok(true))
}

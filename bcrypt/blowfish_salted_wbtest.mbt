// Salted vectors generated with Blowfish from OpenSSH, from Go's TestSaltedCipher.
// Source: https://github.com/golang/crypto/blob/master/blowfish/blowfish_test.go
//
// Copyright 2010 The Go Authors. All rights reserved.
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
fn test_salted_encrypt(
  key : BytesView,
  salt : BytesView,
  l : UInt,
  r : UInt,
) -> (UInt, UInt) {
  let state = new_blowfish_state()
  // Go's NewSaltedCipher uses ordinary key expansion for an empty salt.
  if salt.length() == 0 {
    blowfish_expand_zero_key(state, key)
  } else {
    blowfish_expand_key(state, salt, key)
  }
  blowfish_encrypt_block(state, l, r)
}

///|
test "blowfish salted reference vectors" {
  let key = Bytes::makei(32, i => i.to_byte())
  let salt = Bytes::makei(32, i => (i + 32).to_byte())
  let ciphertexts : Array[(UInt, UInt)] = [
    (0x0C823B7B, 0x8D014B7E),
    (0xD1E193F0, 0x70A6DB12),
    (0xFC5EBADE, 0xCBF859AD),
    (0x8A0C76E7, 0xDD2CD3A8),
    (0x2CCB7BEE, 0xAC7B7FF8),
    (0xBBF6306F, 0xE15D62BF),
    (0x971EC13D, 0x3DE011E9),
    (0x06D74DB1, 0x80A3B138),
    (0x67A1A975, 0x0E5BC6B4),
    (0x510F330E, 0x4F67D20C),
    (0xF1737ED8, 0x44EADBE5),
    (0x140E16CE, 0x7F4A9C7B),
    (0x4BFE43FD, 0xBF360447),
    (0xB1EB3E15, 0x36A7BBE2),
    (0x6D0B41DD, 0x00980B19),
    (0xD3CE45CE, 0x1D56B7FC),
    (0xD9F0FDDA, 0xC023B793),
    (0x4C6FA1E4, 0x0CA8CA57),
    (0xE62F28A7, 0x0C940D08),
    (0x8FE3F0B6, 0x29E34403),
    (0xFF98DD04, 0x45B46D1F),
    (0x9E454D18, 0x4053DBEF),
    (0xB73BEF29, 0xBEA81371),
    (0x02545541, 0x8E04FCAD),
    (0x6A0AEE7C, 0x10D919FE),
    (0x0A22D941, 0xCC238713),
    (0x6EFF1FFF, 0x36179CBE),
    (0x79ADB740, 0xF49F51A6),
    (0x978199A4, 0xDE9E9FB6),
    (0x12197A28, 0xD0DCCC92),
    (0x81DA601E, 0x0EDD6556),
    (0x7D7620B2, 0x73C99EEE),
  ]
  for salt_length, expected in ciphertexts {
    assert_eq(
      test_salted_encrypt(key, salt[:salt_length], 0, 0),
      expected,
      msg="salt length \{salt_length}",
    )
  }
}

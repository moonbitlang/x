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
fn reference_salt() -> Bytes {
  Bytes::from_array([
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
}

///|
test "hash reference vectors" {
  let salt = reference_salt()
  assert_eq(
    @bcrypt.hash(password=b"", salt~, cost=4),
    "$2b$04$abcdefghijklmnopqrstuubyCG3zY1GIXMyxfivm.ClDiInHzxjiq",
  )
  assert_eq(
    @bcrypt.hash(password=b"password", salt~, cost=4),
    "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm",
  )
  assert_eq(
    @bcrypt.hash(password=b"OrpheanBeholderScryDoubt", salt~, cost=5),
    "$2b$05$abcdefghijklmnopqrstuurtwlUrYDZP2QPv/CTj2dee5s1xzF2E.",
  )
  assert_eq(
    @bcrypt.hash(
      password=Bytes::from_array([
        (1).to_byte(),
        (2).to_byte(),
        (3).to_byte(),
        (4).to_byte(),
        (5).to_byte(),
        (6).to_byte(),
        (7).to_byte(),
        (8).to_byte(),
        (9).to_byte(),
        (10).to_byte(),
        (11).to_byte(),
        (12).to_byte(),
        (13).to_byte(),
        (14).to_byte(),
        (15).to_byte(),
        (16).to_byte(),
      ]),
      salt~,
      cost=5,
    ),
    "$2b$05$abcdefghijklmnopqrstuum6yhm2pYarTp4ZS94q20AeKcVy8gCWu",
  )
}

///|
test "password length boundaries at 71, 72, and 73 bytes" {
  let salt = reference_salt()
  let a71 = Bytes::make(71, b'a')
  let a72 = Bytes::make(72, b'a')
  let a73 = Bytes::make(73, b'a')
  // The 71-byte reference value was checked with pyca/bcrypt 5.0.0.
  let hash71 = "$2b$05$abcdefghijklmnopqrstuuldF68XqW1jV1pTkp5QRjAP2izYsMp1u"
  let hash72 = "$2b$05$abcdefghijklmnopqrstuuGUnCqbfgs3htOkLrFduUjAyLBw1Rq/u"
  assert_eq(@bcrypt.hash(password=a71, salt~, cost=5), hash71)
  assert_eq(@bcrypt.hash(password=a72, salt~, cost=5), hash72)
  assert_eq(@bcrypt.hash(password=a73, salt~, cost=5), hash72)
  assert_eq(@bcrypt.verify(password=a71, hashed=hash71), true)
  assert_eq(@bcrypt.verify(password=a71, hashed=hash72), false)
  assert_eq(@bcrypt.verify(password=a72, hashed=hash72), true)
  assert_eq(@bcrypt.verify(password=a73, hashed=hash72), true)
  // The 72nd byte participates; bytes starting at the 73rd are ignored.
  assert_eq(@bcrypt.verify(password=a71 + b"b", hashed=hash72), false)
  assert_eq(@bcrypt.verify(password=a72 + b"b", hashed=hash72), true)
  assert_eq(@bcrypt.verify(password=a72 + b"bcdefghi", hashed=hash72), true)
}

///|
test "verify accepts 2b and 2y" {
  let hash = "$2b$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu"
  let y_hash = "$2y$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu"
  assert_eq(@bcrypt.verify(password=b"password", hashed=hash), true)
  assert_eq(@bcrypt.verify(password=b"wrong", hashed=hash), false)
  assert_eq(@bcrypt.verify(password=b"password", hashed=y_hash), true)
}

///|
test "invalid inputs are rejected" {
  try @bcrypt.hash(password=b"password", salt=b"short", cost=4) catch {
    err => assert_true(err is @bcrypt.InvalidSaltLength(5))
  } noraise {
    _ => fail("expected InvalidSaltLength(5)")
  }
  try @bcrypt.hash(password=b"password", salt=reference_salt(), cost=3) catch {
    err => assert_true(err is @bcrypt.InvalidCost(3))
  } noraise {
    _ => fail("expected InvalidCost(3)")
  }
  try @bcrypt.hash(password=b"password", salt=reference_salt(), cost=32) catch {
    err => assert_true(err is @bcrypt.InvalidCost(32))
  } noraise {
    _ => fail("expected InvalidCost(32)")
  }
  try @bcrypt.verify(password=b"password", hashed="short") catch {
    err => assert_true(err is @bcrypt.InvalidHashFormat)
  } noraise {
    _ => fail("expected InvalidHashFormat")
  }
  try
    @bcrypt.verify(
      password=b"password",
      hashed="$2a$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu",
    )
  catch {
    err => assert_true(err is @bcrypt.UnsupportedVersion("2a"))
  } noraise {
    _ => fail("expected UnsupportedVersion(2a)")
  }
  try
    @bcrypt.verify(
      password=b"password",
      hashed="$2b$05$abcdefghijklmnopqrst!!WG29KuyeAicPCJODk1zjyGvyQUU2awu",
    )
  catch {
    err => assert_true(err is @bcrypt.InvalidBase64)
  } noraise {
    _ => fail("expected InvalidBase64")
  }
}

///|
test "verify rejects tampered digests" {
  let hash = "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm"
  assert_eq(@bcrypt.verify(password=b"password", hashed=hash), true)
  // The digest occupies offsets 29..59. '.' also preserves valid padding
  // at the last character while changing the encoded digest bits.
  for index in [29, 44, 59] {
    let tampered = hash[:index].to_owned() + "." + hash[index + 1:].to_owned()
    assert_eq(tampered.length(), 60)
    assert_true(tampered != hash)
    assert_eq(
      @bcrypt.verify(password=b"password", hashed=tampered),
      false,
      msg="digest offset \{index}",
    )
  }
}

///|
test "invalid salt lengths are rejected" {
  for length in [0, 15, 17] {
    try
      @bcrypt.hash(password=b"password", salt=Bytes::make(length, 0), cost=4)
    catch {
      err =>
        assert_true(
          err is @bcrypt.InvalidSaltLength(actual) && actual == length,
          msg="salt length \{length}",
        )
    } noraise {
      _ => fail("expected InvalidSaltLength(\{length})")
    }
  }
}

///|
test "invalid hash lengths are rejected" {
  let hash = "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm"
  let short_hash = hash[:59].to_owned()
  let long_hash = hash + "."
  assert_eq(short_hash.length(), 59)
  assert_eq(long_hash.length(), 61)
  for invalid_hash in [short_hash, long_hash] {
    try @bcrypt.verify(password=b"password", hashed=invalid_hash) catch {
      err => assert_true(err is @bcrypt.InvalidHashFormat, msg=invalid_hash)
    } noraise {
      _ => fail("expected InvalidHashFormat: \{invalid_hash}")
    }
  }
}

///|
test "invalid cost digits and separators are rejected" {
  let hash = "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm"
  // Replace each cost digit and each '$' separator independently.
  for index in [4, 5, 0, 3, 6] {
    let invalid_hash = hash[:index].to_owned() +
      "x" +
      hash[index + 1:].to_owned()
    assert_eq(invalid_hash.length(), 60)
    try @bcrypt.verify(password=b"password", hashed=invalid_hash) catch {
      err =>
        assert_true(
          err is @bcrypt.InvalidHashFormat,
          msg="hash offset \{index}",
        )
    } noraise {
      _ => fail("expected InvalidHashFormat at hash offset \{index}")
    }
  }
}

///|
test "invalid digest Base64 characters are rejected" {
  let hash = "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm"
  for index in [29, 44, 59] {
    let invalid_hash = hash[:index].to_owned() +
      "!" +
      hash[index + 1:].to_owned()
    assert_eq(invalid_hash.length(), 60)
    try @bcrypt.verify(password=b"password", hashed=invalid_hash) catch {
      err =>
        assert_true(err is @bcrypt.InvalidBase64, msg="digest offset \{index}")
    } noraise {
      _ => fail("expected InvalidBase64 at digest offset \{index}")
    }
  }
}

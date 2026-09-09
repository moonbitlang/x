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
test "hash_password reference vectors" {
  let salt = reference_salt()
  assert_eq(
    @bcrypt.hash_password(b"", salt, 4).unwrap(),
    "$2b$04$abcdefghijklmnopqrstuubyCG3zY1GIXMyxfivm.ClDiInHzxjiq",
  )
  assert_eq(
    @bcrypt.hash_password(b"password", salt, 4).unwrap(),
    "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm",
  )
  assert_eq(
    @bcrypt.hash_password(b"OrpheanBeholderScryDoubt", salt, 5).unwrap(),
    "$2b$05$abcdefghijklmnopqrstuurtwlUrYDZP2QPv/CTj2dee5s1xzF2E.",
  )
  assert_eq(
    @bcrypt.hash_password(
      Bytes::from_array([
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
      salt,
      5,
    ).unwrap(),
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
  assert_eq(@bcrypt.hash_password(a71, salt, 5), Ok(hash71))
  assert_eq(@bcrypt.hash_password(a72, salt, 5), Ok(hash72))
  assert_eq(@bcrypt.hash_password(a73, salt, 5), Ok(hash72))
  assert_eq(@bcrypt.verify(a71, hash71), Ok(true))
  assert_eq(@bcrypt.verify(a71, hash72), Ok(false))
  assert_eq(@bcrypt.verify(a72, hash72), Ok(true))
  assert_eq(@bcrypt.verify(a73, hash72), Ok(true))
  // The 72nd byte participates; bytes starting at the 73rd are ignored.
  assert_eq(@bcrypt.verify(a71 + b"b", hash72), Ok(false))
  assert_eq(@bcrypt.verify(a72 + b"b", hash72), Ok(true))
  assert_eq(@bcrypt.verify(a72 + b"bcdefghi", hash72), Ok(true))
}

///|
test "verify accepts 2b and 2y" {
  let hash = "$2b$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu"
  let y_hash = "$2y$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu"
  assert_eq(@bcrypt.verify(b"password", hash).unwrap(), true)
  assert_eq(@bcrypt.verify(b"wrong", hash).unwrap(), false)
  assert_eq(@bcrypt.verify(b"password", y_hash).unwrap(), true)
  assert_eq(@bcrypt.cost(hash).unwrap(), 5)
}

///|
test "invalid inputs are rejected" {
  let short_salt = @bcrypt.hash_password(b"password", b"short", 4)
  assert_true(short_salt is Err(@bcrypt.InvalidSaltLength(5)))
  let low_cost = @bcrypt.hash_password(b"password", reference_salt(), 3)
  assert_true(low_cost is Err(@bcrypt.InvalidCost(3)))
  let high_cost = @bcrypt.hash_password(b"password", reference_salt(), 32)
  assert_true(high_cost is Err(@bcrypt.InvalidCost(32)))
  let short_hash = @bcrypt.verify(b"password", "short")
  assert_true(short_hash is Err(@bcrypt.InvalidHashFormat))
  let old_version = @bcrypt.verify(
    b"password", "$2a$05$abcdefghijklmnopqrstuuWG29KuyeAicPCJODk1zjyGvyQUU2awu",
  )
  assert_true(old_version is Err(@bcrypt.UnsupportedVersion("2a")))
  let bad_base64 = @bcrypt.verify(
    b"password", "$2b$05$abcdefghijklmnopqrst!!WG29KuyeAicPCJODk1zjyGvyQUU2awu",
  )
  assert_true(bad_base64 is Err(@bcrypt.InvalidBase64))
}

///|
test "verify rejects tampered digests" {
  let hash = "$2b$04$abcdefghijklmnopqrstuughE8Ev8uGFaUgY2cNEySvxngrb/Jzdm"
  assert_eq(@bcrypt.verify(b"password", hash), Ok(true))
  // The digest occupies offsets 29..59. '.' also preserves valid padding
  // at the last character while changing the encoded digest bits.
  for index in [29, 44, 59] {
    let tampered = hash[:index].to_owned() + "." + hash[index + 1:].to_owned()
    assert_eq(tampered.length(), 60)
    assert_true(tampered != hash)
    assert_eq(@bcrypt.cost(tampered), Ok(4), msg="digest offset \{index}")
    assert_eq(
      @bcrypt.verify(b"password", tampered),
      Ok(false),
      msg="digest offset \{index}",
    )
  }
}

///|
test "invalid salt lengths are rejected" {
  for length in [0, 15, 17] {
    let result = @bcrypt.hash_password(b"password", Bytes::make(length, 0), 4)
    assert_true(
      result is Err(@bcrypt.InvalidSaltLength(actual)) && actual == length,
      msg="salt length \{length}",
    )
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
    assert_true(
      @bcrypt.cost(invalid_hash) is Err(@bcrypt.InvalidHashFormat),
      msg=invalid_hash,
    )
    assert_true(
      @bcrypt.verify(b"password", invalid_hash)
      is Err(@bcrypt.InvalidHashFormat),
      msg=invalid_hash,
    )
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
    assert_true(
      @bcrypt.cost(invalid_hash) is Err(@bcrypt.InvalidHashFormat),
      msg="hash offset \{index}",
    )
    assert_true(
      @bcrypt.verify(b"password", invalid_hash)
      is Err(@bcrypt.InvalidHashFormat),
      msg="hash offset \{index}",
    )
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
    assert_true(
      @bcrypt.cost(invalid_hash) is Err(@bcrypt.InvalidBase64),
      msg="digest offset \{index}",
    )
    assert_true(
      @bcrypt.verify(b"password", invalid_hash) is Err(@bcrypt.InvalidBase64),
      msg="digest offset \{index}",
    )
  }
}

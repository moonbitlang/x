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
test "passwords longer than 72 bytes are truncated" {
  let salt = reference_salt()
  let a72 = Bytes::make(72, (97).to_byte())
  let a73 = Bytes::make(73, (97).to_byte())
  assert_eq(
    @bcrypt.hash_password(a72, salt, 5).unwrap(),
    @bcrypt.hash_password(a73, salt, 5).unwrap(),
  )
  assert_eq(
    @bcrypt.hash_password(a73, salt, 5).unwrap(),
    "$2b$05$abcdefghijklmnopqrstuuGUnCqbfgs3htOkLrFduUjAyLBw1Rq/u",
  )
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

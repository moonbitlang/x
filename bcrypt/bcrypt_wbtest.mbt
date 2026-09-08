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

///|
test "blowfish known vector" {
  let state = new_blowfish_state()
  blowfish_expand_zero_key(state, Bytes::make(8, (0).to_byte()).view())
  let (l, r) = blowfish_encrypt_block(state, 0U, 0U)
  assert_eq(l, 0x4ef99745U)
  assert_eq(r, 0x6198dd78U)
}

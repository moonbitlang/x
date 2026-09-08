# hackwaly/bcrypt

Pure MoonBit bcrypt core implementation.

```mbt nocheck
///|
test "bcrypt example" {
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
  let hash = @bcrypt.hash_password(b"password", salt, 4).unwrap()
  assert_eq(@bcrypt.verify(b"password", hash), Ok(true))
  assert_eq(@bcrypt.verify(b"wrong", hash), Ok(false))
}
```

// ECB and variable key length vectors by Eric Young (16 rounds).
// Source: https://www.schneier.com/wp-content/uploads/2015/12/vectors-2.txt

///|
fn test_encrypt(key : BytesView, l : UInt, r : UInt) -> (UInt, UInt) {
  let state = new_blowfish_state()
  blowfish_expand_zero_key(state, key)
  blowfish_encrypt_block(state, l, r)
}

///|
test "blowfish ECB reference vectors" {
  // Key, plaintext, and ciphertext; blocks are pairs of big-endian words.
  let vectors : Array[(Bytes, (UInt, UInt), (UInt, UInt))] = [
    (
      b"\x00\x00\x00\x00\x00\x00\x00\x00",
      (0x00000000U, 0x00000000U),
      (0x4EF99745U, 0x6198DD78U),
    ),
    (
      b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
      (0xFFFFFFFFU, 0xFFFFFFFFU),
      (0x51866FD5U, 0xB85ECB8AU),
    ),
    (
      b"\x30\x00\x00\x00\x00\x00\x00\x00",
      (0x10000000U, 0x00000001U),
      (0x7D856F9AU, 0x613063F2U),
    ),
    (
      b"\x11\x11\x11\x11\x11\x11\x11\x11",
      (0x11111111U, 0x11111111U),
      (0x2466DD87U, 0x8B963C9DU),
    ),
    (
      b"\x01\x23\x45\x67\x89\xAB\xCD\xEF",
      (0x11111111U, 0x11111111U),
      (0x61F9C380U, 0x2281B096U),
    ),
    (
      b"\x11\x11\x11\x11\x11\x11\x11\x11",
      (0x01234567U, 0x89ABCDEFU),
      (0x7D0CC630U, 0xAFDA1EC7U),
    ),
    (
      b"\x00\x00\x00\x00\x00\x00\x00\x00",
      (0x00000000U, 0x00000000U),
      (0x4EF99745U, 0x6198DD78U),
    ),
    (
      b"\xFE\xDC\xBA\x98\x76\x54\x32\x10",
      (0x01234567U, 0x89ABCDEFU),
      (0x0ACEAB0FU, 0xC6A0A28DU),
    ),
    (
      b"\x7C\xA1\x10\x45\x4A\x1A\x6E\x57",
      (0x01A1D6D0U, 0x39776742U),
      (0x59C68245U, 0xEB05282BU),
    ),
    (
      b"\x01\x31\xD9\x61\x9D\xC1\x37\x6E",
      (0x5CD54CA8U, 0x3DEF57DAU),
      (0xB1B8CC0BU, 0x250F09A0U),
    ),
    (
      b"\x07\xA1\x13\x3E\x4A\x0B\x26\x86",
      (0x0248D438U, 0x06F67172U),
      (0x1730E577U, 0x8BEA1DA4U),
    ),
    (
      b"\x38\x49\x67\x4C\x26\x02\x31\x9E",
      (0x51454B58U, 0x2DDF440AU),
      (0xA25E7856U, 0xCF2651EBU),
    ),
    (
      b"\x04\xB9\x15\xBA\x43\xFE\xB5\xB6",
      (0x42FD4430U, 0x59577FA2U),
      (0x353882B1U, 0x09CE8F1AU),
    ),
    (
      b"\x01\x13\xB9\x70\xFD\x34\xF2\xCE",
      (0x059B5E08U, 0x51CF143AU),
      (0x48F4D088U, 0x4C379918U),
    ),
    (
      b"\x01\x70\xF1\x75\x46\x8F\xB5\xE6",
      (0x0756D8E0U, 0x774761D2U),
      (0x432193B7U, 0x8951FC98U),
    ),
    (
      b"\x43\x29\x7F\xAD\x38\xE3\x73\xFE",
      (0x762514B8U, 0x29BF486AU),
      (0x13F04154U, 0xD69D1AE5U),
    ),
    (
      b"\x07\xA7\x13\x70\x45\xDA\x2A\x16",
      (0x3BDD1190U, 0x49372802U),
      (0x2EEDDA93U, 0xFFD39C79U),
    ),
    (
      b"\x04\x68\x91\x04\xC2\xFD\x3B\x2F",
      (0x26955F68U, 0x35AF609AU),
      (0xD887E039U, 0x3C2DA6E3U),
    ),
    (
      b"\x37\xD0\x6B\xB5\x16\xCB\x75\x46",
      (0x164D5E40U, 0x4F275232U),
      (0x5F99D04FU, 0x5B163969U),
    ),
    (
      b"\x1F\x08\x26\x0D\x1A\xC2\x46\x5E",
      (0x6B056E18U, 0x759F5CCAU),
      (0x4A057A3BU, 0x24D3977BU),
    ),
    (
      b"\x58\x40\x23\x64\x1A\xBA\x61\x76",
      (0x004BD6EFU, 0x09176062U),
      (0x452031C1U, 0xE4FADA8EU),
    ),
    (
      b"\x02\x58\x16\x16\x46\x29\xB0\x07",
      (0x480D3900U, 0x6EE762F2U),
      (0x7555AE39U, 0xF59B87BDU),
    ),
    (
      b"\x49\x79\x3E\xBC\x79\xB3\x25\x8F",
      (0x437540C8U, 0x698F3CFAU),
      (0x53C55F9CU, 0xB49FC019U),
    ),
    (
      b"\x4F\xB0\x5E\x15\x15\xAB\x73\xA7",
      (0x072D43A0U, 0x77075292U),
      (0x7A8E7BFAU, 0x937E89A3U),
    ),
    (
      b"\x49\xE9\x5D\x6D\x4C\xA2\x29\xBF",
      (0x02FE5577U, 0x8117F12AU),
      (0xCF9C5D7AU, 0x4986ADB5U),
    ),
    (
      b"\x01\x83\x10\xDC\x40\x9B\x26\xD6",
      (0x1D9D5C50U, 0x18F728C2U),
      (0xD1ABB290U, 0x658BC778U),
    ),
    (
      b"\x1C\x58\x7F\x1C\x13\x92\x4F\xEF",
      (0x30553228U, 0x6D6F295AU),
      (0x55CB3774U, 0xD13EF201U),
    ),
    (
      b"\x01\x01\x01\x01\x01\x01\x01\x01",
      (0x01234567U, 0x89ABCDEFU),
      (0xFA34EC48U, 0x47B268B2U),
    ),
    (
      b"\x1F\x1F\x1F\x1F\x0E\x0E\x0E\x0E",
      (0x01234567U, 0x89ABCDEFU),
      (0xA7907951U, 0x08EA3CAEU),
    ),
    (
      b"\xE0\xFE\xE0\xFE\xF1\xFE\xF1\xFE",
      (0x01234567U, 0x89ABCDEFU),
      (0xC39E072DU, 0x9FAC631DU),
    ),
    (
      b"\x00\x00\x00\x00\x00\x00\x00\x00",
      (0xFFFFFFFFU, 0xFFFFFFFFU),
      (0x014933E0U, 0xCDAFF6E4U),
    ),
    (
      b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
      (0x00000000U, 0x00000000U),
      (0xF21E9A77U, 0xB71C49BCU),
    ),
    (
      b"\x01\x23\x45\x67\x89\xAB\xCD\xEF",
      (0x00000000U, 0x00000000U),
      (0x24594688U, 0x5754369AU),
    ),
    (
      b"\xFE\xDC\xBA\x98\x76\x54\x32\x10",
      (0xFFFFFFFFU, 0xFFFFFFFFU),
      (0x6B5C5A9CU, 0x5D9E0A5AU),
    ),
  ]
  for index, vector in vectors {
    let (key, (l, r), expected) = vector
    assert_eq(test_encrypt(key, l, r), expected, msg="ECB vector \{index + 1}")
  }
}

///|
test "blowfish variable key length reference vectors" {
  // Test key lengths from 1 to 24 bytes using prefixes of this key.
  let key = b"\xF0\xE1\xD2\xC3\xB4\xA5\x96\x87\x78\x69\x5A\x4B\x3C\x2D\x1E\x0F\x00\x11\x22\x33\x44\x55\x66\x77"
  let ciphertexts : Array[(UInt, UInt)] = [
    (0xF9AD597C, 0x49DB005E),
    (0xE91D21C1, 0xD961A6D6),
    (0xE9C2B70A, 0x1BC65CF3),
    (0xBE1E6394, 0x08640F05),
    (0xB39E4448, 0x1BDB1E6E),
    (0x9457AA83, 0xB1928C0D),
    (0x8BB77032, 0xF960629D),
    (0xE87A244E, 0x2CC85E82),
    (0x15750E7A, 0x4F4EC577),
    (0x122BA70B, 0x3AB64AE0),
    (0x3A833C9A, 0xFFC537F6),
    (0x9409DA87, 0xA90F6BF2),
    (0x884F8062, 0x5060B8B4),
    (0x1F85031C, 0x19E11968),
    (0x79D9373A, 0x714CA34F),
    (0x93142887, 0xEE3BE15C),
    (0x03429E83, 0x8CE2D14B),
    (0xA4299E27, 0x469FF67B),
    (0xAFD5AED1, 0xC1BC96A8),
    (0x10851C0E, 0x3858DA9F),
    (0xE6F51ED7, 0x9B9DB21F),
    (0x64A6E14A, 0xFD36B46F),
    (0x80C7D7D4, 0x5A5479AD),
    (0x05044B62, 0xFA52D080),
  ]
  for index, expected in ciphertexts {
    let key_length = index + 1
    assert_eq(
      test_encrypt(key[:key_length], 0xFEDCBA98, 0x76543210),
      expected,
      msg="key length \{key_length}",
    )
  }
}

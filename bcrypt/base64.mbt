///|
let bcrypt_alphabet : Bytes = b"./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

///|
fn bcrypt_base64_encode(bytes : BytesView, length : Int) -> String {
  let builder = StringBuilder(size_hint=(length * 4 + 2) / 3)
  let mut offset = 0
  while offset < length {
    let c1 = bytes[offset].to_int()
    offset += 1
    builder.write_char(bcrypt_alphabet[c1 >> 2].to_char())
    let mut c = (c1 & 0x03) << 4
    if offset >= length {
      builder.write_char(bcrypt_alphabet[c].to_char())
      break
    }
    let c2 = bytes[offset].to_int()
    offset += 1
    c = c | ((c2 & 0xf0) >> 4)
    builder.write_char(bcrypt_alphabet[c].to_char())
    c = (c2 & 0x0f) << 2
    if offset >= length {
      builder.write_char(bcrypt_alphabet[c].to_char())
      break
    }
    let c3 = bytes[offset].to_int()
    offset += 1
    c = c | ((c3 & 0xc0) >> 6)
    builder.write_char(bcrypt_alphabet[c].to_char())
    builder.write_char(bcrypt_alphabet[c3 & 0x3f].to_char())
  }
  builder.to_string()
}

///|
fn bcrypt_base64_decode(
  text : String,
  max_length : Int,
) -> Result[Bytes, BcryptError] {
  let out = Array::new(capacity=max_length)
  let mut offset = 0
  while offset < text.length() - 1 && out.length() < max_length {
    let c1 = bcrypt_base64_index(text[offset].to_int())
    let c2 = bcrypt_base64_index(text[offset + 1].to_int())
    if c1 < 0 || c2 < 0 {
      return Err(InvalidBase64)
    }
    offset += 2
    out.push(((c1 << 2) | ((c2 & 0x30) >> 4)).to_byte())
    if out.length() >= max_length || offset >= text.length() {
      break
    }
    let c3 = bcrypt_base64_index(text[offset].to_int())
    if c3 < 0 {
      return Err(InvalidBase64)
    }
    offset += 1
    out.push((((c2 & 0x0f) << 4) | ((c3 & 0x3c) >> 2)).to_byte())
    if out.length() >= max_length || offset >= text.length() {
      break
    }
    let c4 = bcrypt_base64_index(text[offset].to_int())
    if c4 < 0 {
      return Err(InvalidBase64)
    }
    offset += 1
    out.push((((c3 & 0x03) << 6) | c4).to_byte())
  }
  if out.length() == max_length {
    Ok(Bytes::from_array(out.view()))
  } else {
    Err(InvalidBase64)
  }
}

///|
fn bcrypt_base64_all_valid(text : String) -> Bool {
  for i in 0..<text.length() {
    if bcrypt_base64_index(text[i].to_int()) < 0 {
      return false
    }
  }
  true
}

///|
fn bcrypt_base64_index(code : Int) -> Int {
  match code {
    46 => 0 // .
    47 => 1 // /
    65..=90 => code - 65 + 2
    97..=122 => code - 97 + 28
    48..=57 => code - 48 + 54
    _ => -1
  }
}

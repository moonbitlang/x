///|
let magic_cipher_data : Bytes = b"OrpheanBeholderScryDoubt"

///|
fn bcrypt_hash_raw(password : BytesView, salt : BytesView, cost : Int) -> Bytes {
  let key = bcrypt_key(password)
  let state = new_blowfish_state()
  blowfish_expand_key(state, salt, key.view())
  let rounds : UInt = 1U << cost
  for _ in 0U..<rounds {
    blowfish_expand_zero_key(state, key.view())
    blowfish_expand_zero_key(state, salt)
  }

  let cdata = Array::new(capacity=6)
  let mut off = 0
  for _ in 0..<6 {
    let (word, next_off) = stream_to_word(magic_cipher_data.view(), off)
    cdata.push(word)
    off = next_off
  }
  for _ in 0..<64 {
    for j in 0..<3 {
      let (l, r) = blowfish_encrypt_block(state, cdata[j * 2], cdata[j * 2 + 1])
      cdata[j * 2] = l
      cdata[j * 2 + 1] = r
    }
  }

  let out = Array::new(capacity=24)
  for i in 0..<6 {
    out.push((cdata[i] >> 24).to_byte())
    out.push((cdata[i] >> 16).to_byte())
    out.push((cdata[i] >> 8).to_byte())
    out.push(cdata[i].to_byte())
  }
  Bytes::from_array(out.view())
}

///|
fn bcrypt_key(password : BytesView) -> Bytes {
  let n = if password.length() > 72 { 72 } else { password.length() }
  Bytes::makei(n + 1, fn(i) { if i < n { password[i] } else { (0).to_byte() } })
}

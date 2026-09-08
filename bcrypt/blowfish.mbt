///|
priv struct BlowfishState {
  p : Array[UInt]
  s : Array[UInt]
}

///|
fn new_blowfish_state() -> BlowfishState {
  { p: init_p.copy(), s: init_s.copy() }
}

///|
fn blowfish_f(state : BlowfishState, x : UInt) -> UInt {
  let a = ((x >> 24) & 0xffU).reinterpret_as_int()
  let b = ((x >> 16) & 0xffU).reinterpret_as_int()
  let c = ((x >> 8) & 0xffU).reinterpret_as_int()
  let d = (x & 0xffU).reinterpret_as_int()
  ((state.s[a] + state.s[0x100 + b]) ^ state.s[0x200 + c]) + state.s[0x300 + d]
}

///|
fn blowfish_encrypt_block(
  state : BlowfishState,
  l0 : UInt,
  r0 : UInt,
) -> (UInt, UInt) {
  let mut l = l0
  let mut r = r0
  for i in 0..<16 {
    l = l ^ state.p[i]
    r = blowfish_f(state, l) ^ r
    let t = l
    l = r
    r = t
  }
  let t = l
  l = r
  r = t
  r = r ^ state.p[16]
  l = l ^ state.p[17]
  (l, r)
}

///|
fn stream_to_word(data : BytesView, offset : Int) -> (UInt, Int) {
  let mut word = 0U
  let mut off = offset
  for _ in 0..<4 {
    word = (word << 8) | data[off].to_uint()
    off += 1
    if off == data.length() {
      off = 0
    }
  }
  (word, off)
}

///|
fn blowfish_expand_key(
  state : BlowfishState,
  salt : BytesView,
  key : BytesView,
) -> Unit {
  let mut key_off = 0
  for i in 0..<18 {
    let (word, next_key_off) = stream_to_word(key, key_off)
    state.p[i] = state.p[i] ^ word
    key_off = next_key_off
  }

  let mut salt_off = 0
  let mut l = 0U
  let mut r = 0U
  for i in 0..<9 {
    let (salt_l, next_salt_off) = stream_to_word(salt, salt_off)
    salt_off = next_salt_off
    let (salt_r, next_salt_off2) = stream_to_word(salt, salt_off)
    salt_off = next_salt_off2
    l = l ^ salt_l
    r = r ^ salt_r
    let (new_l, new_r) = blowfish_encrypt_block(state, l, r)
    l = new_l
    r = new_r
    state.p[i * 2] = l
    state.p[i * 2 + 1] = r
  }

  for i in 0..<512 {
    let (salt_l, next_salt_off) = stream_to_word(salt, salt_off)
    salt_off = next_salt_off
    let (salt_r, next_salt_off2) = stream_to_word(salt, salt_off)
    salt_off = next_salt_off2
    l = l ^ salt_l
    r = r ^ salt_r
    let (new_l, new_r) = blowfish_encrypt_block(state, l, r)
    l = new_l
    r = new_r
    state.s[i * 2] = l
    state.s[i * 2 + 1] = r
  }
}

///|
fn blowfish_expand_zero_key(state : BlowfishState, key : BytesView) -> Unit {
  let mut key_off = 0
  for i in 0..<18 {
    let (word, next_key_off) = stream_to_word(key, key_off)
    state.p[i] = state.p[i] ^ word
    key_off = next_key_off
  }

  let mut l = 0U
  let mut r = 0U
  for i in 0..<9 {
    let (new_l, new_r) = blowfish_encrypt_block(state, l, r)
    l = new_l
    r = new_r
    state.p[i * 2] = l
    state.p[i * 2 + 1] = r
  }

  for i in 0..<512 {
    let (new_l, new_r) = blowfish_encrypt_block(state, l, r)
    l = new_l
    r = new_r
    state.s[i * 2] = l
    state.s[i * 2 + 1] = r
  }
}

fn codepoint_of_surrogate_pair(high : Int, low : Int) -> Int {
  let h = (high - 0xD800) << 10
  let l = low - 0xDC00
  h + l + 0x10000
}

/// Encode given string (in UTF16-LE) to UTF-8 format
pub fn to_utf8(str : String) -> Bytes!Failure {
  fn utf8_of_codepoint(codepoint : Int) -> Array[Int]!Failure {
    if codepoint <= 0x7F {
      return [codepoint]
    } else if codepoint <= 0x7FF {
      return [0xC0 | (codepoint >> 6), 0x80 | (codepoint & 0x3F)]
    } else if codepoint <= 0xFFFF {
      return [
        0xE0 | (codepoint >> 12),
        0x80 | ((codepoint >> 6) & 0x3F),
        0x80 | (codepoint & 0x3F),
      ]
    } else if codepoint <= 0x10FFFF {
      return [
        0xF0 | (codepoint >> 18),
        0x80 | ((codepoint >> 12) & 0x3F),
        0x80 | ((codepoint >> 6) & 0x3F),
        0x80 | (codepoint & 0x3F),
      ]
    } else {
      fail!("Invalid codepoint")
    }
  }

  /// elements in [arr] is guraranteed to be in [0, 255]
  fn bytes_from_array(arr : Array[Int]) -> Bytes {
    let bytes : Bytes = Bytes::new(arr.length())
    for i, v in arr {
      bytes[i] = v.to_byte()
    }
    bytes
  }

  let mut i = 0
  let acc : Array[Int] = Array::new(capacity=str.length())
  while i < str.length() {
    let high = str[i].to_int()
    if high >= 0xD800 && high <= 0xDBFF {
      if i + 1 < str.length() {
        let low = str[i + 1].to_int()
        if low >= 0xDC00 && low <= 0xDFFF {
          // low surrogate
          let codepoint = codepoint_of_surrogate_pair(high, low)
          acc.append(utf8_of_codepoint!(codepoint))
          i += 2
        } else {
          fail!("Invalid UTF-16 sequence: Missing low surrogate")
        }
      } else {
        fail!("Invalid UTF-16 sequence.")
      }
    } else {
      let codepoint = high
      acc.append(utf8_of_codepoint!(codepoint))
      i = i + 1
    }
  }
  let utf8 = bytes_from_array(acc)
  utf8
}

/// Decode given UTF-8 encoded bytes to a UTF16-LE string
pub fn from_utf8(utf8 : Bytes) -> String!Failure {
  let mut pos = 0
  let acc : Array[Int] = Array::new(capacity=utf8.length())
  fn read_byte() -> Int!Failure {
    if pos >= utf8.length() {
      fail!("Unexpected end of input")
    }
    let b = utf8[pos].to_int()
    pos += 1
    b
  }

  // element in array is guaranteed to < 0xffff
  fn array_to_bytes(arr : Array[Int]) -> Bytes {
    let bytes : Bytes = Bytes::new(arr.length() * 2)
    for i, v in arr {
      bytes[2 * i] = v.to_byte()
      bytes[2 * i + 1] = (v >> 8).to_byte()
    }
    bytes
  }

  while pos < utf8.length() {
    let b1 = read_byte!()
    let mut codepoint : Int = 0
    if (b1 & 0x80) == 0x00 {
      // 1-byte sequence: 0xxxxxxx
      codepoint = b1
    } else if (b1 & 0xE0) == 0xC0 {
      // 2-byte sequence: 110xxxxx 10xxxxxx
      let b2 = read_byte!()
      if (b2 & 0xC0) != 0x80 {
        fail!("Invalid UTF-8 sequence")
      }
      codepoint = ((b1 & 0x1F) << 6) | (b2 & 0x3F)
      if codepoint < 0x80 {
        fail!("Overlong encoding")
      }
    } else if (b1 & 0xF0) == 0xE0 {
      // 3-byte sequence: 1110xxxx 10xxxxxx 10xxxxxx
      let b2 = read_byte!()
      let b3 = read_byte!()
      if (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80 {
        fail!("Invalid UTF-8 sequence")
      }
      codepoint = ((b1 & 0x0F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F)
      if codepoint < 0x800 {
        fail!("Overlong encoding")
      }
      if codepoint >= 0xD800 && codepoint <= 0xDFFF {
        fail!("Invalid codepoint (surrogate code point)")
      }
    } else if (b1 & 0xF8) == 0xF0 {
      // 4-byte sequence: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
      let b2 = read_byte!()
      let b3 = read_byte!()
      let b4 = read_byte!()
      if (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80 || (b4 & 0xC0) != 0x80 {
        fail!("Invalid UTF-8 sequence")
      }
      codepoint = ((b1 & 0x07) << 18) |
        ((b2 & 0x3F) << 12) |
        ((b3 & 0x3F) << 6) |
        (b4 & 0x3F)
      if codepoint < 0x10000 || codepoint > 0x10FFFF {
        fail!("Invalid codepoint")
      }
    } else {
      fail!("Invalid UTF-8 sequence")
    }

    // Convert codepoint to UTF-16 code units
    if codepoint <= 0xFFFF {
      acc.push(codepoint)
    } else {
      let cp_prime = codepoint - 0x10000
      let high_surrogate = 0xD800 + (cp_prime >> 10)
      let low_surrogate = 0xDC00 + (cp_prime & 0x3FF)
      acc.push(high_surrogate)
      acc.push(low_surrogate)
    }
  }
  Bytes::to_string(array_to_bytes(acc))
}

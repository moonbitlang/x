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

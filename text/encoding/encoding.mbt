


// pub enum Encoding {
//   UTF16(BOM)
//   UTF16BE
//   UTF16LE
//   UTF8
// }

// pub enum Endian {
//   LittleEndian
//   BigEndian
// }

// /// encode utf16 string to specific text encoding
// pub fn Encoding::encode(encoding: Encoding, str : String) -> Bytes {
//   match encoding {
//     UTF16BE => {
//       for i = 0; i < str.length(); i = i + 1 {
//         str.op_get
//       }
//     }
//     UTF16LE =>{}
//     UTF8 => {}
//   }
//   abort("TODO")
// }

// /// encode string to specific text encoding and write into buffer
// pub fn encode_into(self : Encoding, str : String, buf : Buffer) -> Unit {
//   abort("TODO: need Buffer::write_byte")
// }

// /// decode specific text encoding to string
// pub fn decode(self : Encoding, bytes : Bytes) -> Result[String,String] {
//   abort("TODO: need unsafe_bytes_to_string primitive")
// }

// test {
//   let a = encode(UTF16(LittleEndian), "abc")
//   let b = decode(UTF16(LittleEndian), a)
// }
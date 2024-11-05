// Copyright 2024 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

pub fn read_file_to_string(path : String) -> String {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  let res = read_file_to_bytes_ffi(path_bytes)
  utf8_bytes_to_mbt_string(res)
}

pub fn read_file_to_bytes(path : String) -> Bytes {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  read_file_to_bytes_ffi(path_bytes)
}

extern "C" fn read_file_to_bytes_ffi(path : Bytes) -> Bytes = "read_file_to_bytes"

pub fn write_string_to_file(path : String, content : String) -> Unit {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  let content_bytes = mbt_string_to_utf8_bytes(content)
  write_bytes_to_file_ffi(path_bytes, content_bytes)
}

pub fn write_bytes_to_file(path : String, content : Bytes) -> Unit {
  let path = mbt_string_to_utf8_bytes(path)
  write_bytes_to_file_ffi(path, content)
}

extern "C" fn write_bytes_to_file_ffi(path : Bytes, content : Bytes) = "write_bytes_to_file"

pub fn path_exists(path : String) -> Bool {
  path_exists_ffi(mbt_string_to_utf8_bytes(path)) == 0
}

extern "C" fn path_exists_ffi(path : Bytes) -> Int = "path_exists"

pub fn read_dir(path : String) -> Array[String] {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  let res = read_dir_ffi(path_bytes).map(utf8_bytes_to_mbt_string)
  Array::from_fixed_array(res)
}

extern "C" fn read_dir_ffi(path : Bytes) -> FixedArray[Bytes] = "read_dir"

pub fn create_dir(path : String) -> Unit {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  create_dir_ffi(path_bytes)
}

extern "C" fn create_dir_ffi(path : Bytes) = "create_dir"

pub fn is_dir(path : String) -> Bool {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  is_dir_ffi(path_bytes) == 0
}

extern "C" fn is_dir_ffi(path : Bytes) -> Int = "is_dir"

pub fn is_file(path : String) -> Bool {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  is_file_ffi(path_bytes) == 0
}

extern "C" fn is_file_ffi(path : Bytes) -> Int = "is_file"

pub fn remove_dir(path : String) -> Unit {
  remove_dir_ffi(mbt_string_to_utf8_bytes(path))
}

extern "C" fn remove_dir_ffi(path : Bytes) = "remove_dir"

pub fn remove_file(path : String) -> Unit {
  let path_bytes = mbt_string_to_utf8_bytes(path)
  remove_file_ffi(path_bytes)
}

extern "C" fn remove_file_ffi(path : Bytes) = "remove_file"

fn mbt_string_to_utf8_bytes(str : String) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str[i].to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i = i + 1
      let l = str[i].to_int() - 0xDC00
      c = (c << 10) + l + 0x10000
    }

    // stdout accepts UTF-8, so convert the stream to UTF-8 first
    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xc0 + (c >> 6)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else if c < 0x10000 {
      res.push((0xe0 + (c >> 12)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else {
      res.push((0xf0 + (c >> 18)).to_byte())
      res.push((0x80 + ((c >> 12) & 0x3f)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    }
    i = i + 1
  }
  res.push((0).to_byte())
  Bytes::from_array(res)
}

fn utf8_bytes_to_mbt_string(bytes : Bytes) -> String {
  let res : Array[Char] = []
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let mut c = bytes[i].to_int()
    if c < 0x80 {
      res.push(Char::from_int(c))
      i += 1
    } else if c < 0xE0 {
      if i + 1 >= len {
        break
      }
      c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      res.push(Char::from_int(c))
      i += 2
    } else if c < 0xF0 {
      if i + 2 >= len {
        break
      }
      c = ((c & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      res.push(Char::from_int(c))
      i += 3
    } else {
      if i + 3 >= len {
        break
      }
      c = ((c & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      c -= 0x10000
      res.push(Char::from_int((c >> 10) + 0xD800))
      res.push(Char::from_int((c & 0x3FF) + 0xDC00))
      i += 4
    }
  }
  String::from_array(res)
}

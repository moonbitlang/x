// Copyright 2025 International Digital Economy Academy
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

///|
#external
priv type XByteArrayCreateHandle

///|
#external
priv type XByteArrayReadHandle

///|
#external
priv type XExternByteArray

///|
fn begin_read_byte_array(s : XExternByteArray) -> XByteArrayReadHandle = "__moonbit_fs_unstable" "begin_read_byte_array"

///|
fn byte_array_read_byte(handle : XByteArrayReadHandle) -> Int32 = "__moonbit_fs_unstable" "byte_array_read_byte"

///|
fn finish_read_byte_array(handle : XByteArrayReadHandle) = "__moonbit_fs_unstable" "finish_read_byte_array"

///|
fn begin_create_byte_array() -> XByteArrayCreateHandle = "__moonbit_fs_unstable" "begin_create_byte_array"

///|
fn byte_array_append_byte(handle : XByteArrayCreateHandle, ch : Int32) = "__moonbit_fs_unstable" "byte_array_append_byte"

///|
fn finish_create_byte_array(
  handle : XByteArrayCreateHandle,
) -> XExternByteArray = "__moonbit_fs_unstable" "finish_create_byte_array"

///|
fn byte_array_to_extern(s : Bytes) -> XExternByteArray {
  let handle = begin_create_byte_array()
  for i = 0; i < s.length(); i = i + 1 {
    byte_array_append_byte(handle, s[i].to_int())
  }
  finish_create_byte_array(handle)
}

///|
fn byte_array_from_extern(e : XExternByteArray) -> Bytes {
  let buf = []
  let handle = begin_read_byte_array(e)
  while true {
    let ch = byte_array_read_byte(handle)
    if ch == -1 {
      break
    } else {
      buf.push(ch.to_byte())
    }
  }
  finish_read_byte_array(handle)
  Bytes::from_array(buf)
}

///|
#external
priv type XStringArrayReadHandle

///|
#external
priv type XExternStringArray

///|
fn begin_read_string_array(sa : XExternStringArray) -> XStringArrayReadHandle = "__moonbit_fs_unstable" "begin_read_string_array"

///|
fn string_array_read_string(handle : XStringArrayReadHandle) -> XExternString = "__moonbit_fs_unstable" "string_array_read_string"

///|
fn finish_read_string_array(handle : XStringArrayReadHandle) = "__moonbit_fs_unstable" "finish_read_string_array"

///|
fn string_array_from_extern(e : XExternStringArray) -> Array[String] {
  let buf = []
  let handle = begin_read_string_array(e)
  while true {
    let extern_str = string_array_read_string(handle)
    let str = string_from_extern(extern_str)
    // keep "ffi_end_of_/string_array" same with moonrun
    if str == "ffi_end_of_/string_array" {
      break
    } else {
      buf.push(str)
    }
  }
  finish_read_string_array(handle)
  buf
}

///|
fn get_file_content_ffi() -> XExternByteArray = "__moonbit_fs_unstable" "get_file_content"

///|
fn get_dir_files_ffi() -> XExternStringArray = "__moonbit_fs_unstable" "get_dir_files"

///|
fn read_file_to_bytes_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "read_file_to_bytes_new"

///|
fn write_bytes_to_file_ffi(
  path : XExternString,
  content : XExternByteArray,
) -> Int32 = "__moonbit_fs_unstable" "write_bytes_to_file_new"

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let res = read_file_to_bytes_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  byte_array_from_extern(get_file_content_ffi())
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let res = write_bytes_to_file_ffi(
    string_to_extern(path),
    byte_array_to_extern(content),
  )
  guard res != -1 else { raise IOError(get_error_message()) }
}

///|
fn path_exists_ffi(path : XExternString) -> Bool = "__moonbit_fs_unstable" "path_exists"

///|
fn path_exists_internal(path : String) -> Bool {
  path_exists_ffi(string_to_extern(path))
}

///|
fn read_dir_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "read_dir_new"

///|
fn read_dir_internal(path : String) -> ArrayView[String] raise IOError {
  let res = read_dir_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  string_array_from_extern(get_dir_files_ffi())[:]
}

///|
fn is_file_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "is_file_new"

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  let res = is_file_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  res == 1
}

///|
fn is_dir_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "is_dir_new"

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  let res = is_dir_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  res == 1
}

///|
fn remove_file_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "remove_file_new"

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  let res = remove_file_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
}

///|
fn remove_dir_ffi(path : XExternString) -> Int32 = "__moonbit_fs_unstable" "remove_dir_new"

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  let res = remove_dir_ffi(string_to_extern(path))
  guard res != -1 else { raise IOError(get_error_message()) }
}

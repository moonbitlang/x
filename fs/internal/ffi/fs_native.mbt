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

///|
pub fn read_file_to_string(path : String) -> String {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  let res = read_file_to_bytes_ffi(path_bytes)
  @ffi.utf8_bytes_to_mbt_string(res)
}

///|
pub fn read_file_to_bytes(path : String) -> Bytes {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  read_file_to_bytes_ffi(path_bytes)
}

///|
extern "C" fn read_file_to_bytes_ffi(path : Bytes) -> Bytes = "read_file_to_bytes"

///|
pub fn write_string_to_file(path : String, content : String) -> Unit {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  let content_bytes = @ffi.mbt_string_to_utf8_bytes(content, false)
  write_bytes_to_file_ffi(path_bytes, content_bytes)
}

///|
pub fn write_bytes_to_file(path : String, content : Bytes) -> Unit {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  write_bytes_to_file_ffi(path_bytes, content)
}

///|
extern "C" fn write_bytes_to_file_ffi(path : Bytes, content : Bytes) = "write_bytes_to_file"

///|
pub fn path_exists(path : String) -> Bool {
  path_exists_ffi(@ffi.mbt_string_to_utf8_bytes(path, true)) == 0
}

///|
extern "C" fn path_exists_ffi(path : Bytes) -> Int = "path_exists"

///|
pub fn read_dir(path : String) -> Array[String] {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  let res = read_dir_ffi(path_bytes).map(@ffi.utf8_bytes_to_mbt_string)
  Array::from_fixed_array(res)
}

///|
extern "C" fn read_dir_ffi(path : Bytes) -> FixedArray[Bytes] = "read_dir"

///|
pub fn create_dir(path : String) -> Unit {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  create_dir_ffi(path_bytes)
}

///|
extern "C" fn create_dir_ffi(path : Bytes) = "create_dir"

///|
pub fn is_dir(path : String) -> Bool {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  is_dir_ffi(path_bytes) == 0
}

///|
extern "C" fn is_dir_ffi(path : Bytes) -> Int = "is_dir"

///|
pub fn is_file(path : String) -> Bool {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  is_file_ffi(path_bytes) == 0
}

///|
extern "C" fn is_file_ffi(path : Bytes) -> Int = "is_file"

///|
pub fn remove_dir(path : String) -> Unit {
  remove_dir_ffi(@ffi.mbt_string_to_utf8_bytes(path, true))
}

///|
extern "C" fn remove_dir_ffi(path : Bytes) = "remove_dir"

///|
pub fn remove_file(path : String) -> Unit {
  let path_bytes = @ffi.mbt_string_to_utf8_bytes(path, true)
  remove_file_ffi(path_bytes)
}

///|
extern "C" fn remove_file_ffi(path : Bytes) = "remove_file"

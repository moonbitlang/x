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


pub fn read_file_to_string(path: String) -> String {
  let path = string_to_extern(path)
  let content = read_file_to_string_ffi(path)
  string_from_extern(content)
}

fn read_file_to_string_ffi(path : XExternString) -> XExternString = "__moonbit_fs_unstable" "read_file_to_string"

pub fn read_file_to_bytes(path : String) -> Bytes {
  let path = string_to_extern(path)
  let content = read_file_to_bytes_ffi(path)
  byte_array_from_extern(content)
}

fn read_file_to_bytes_ffi(path : XExternString) -> XExternByteArray = "__moonbit_fs_unstable" "read_file_to_bytes"

pub fn write_string_to_file(path : String, content : String) -> Unit {
  let path = string_to_extern(path)
  let content = string_to_extern(content)
  write_string_to_file_ffi(path, content)
}

fn write_string_to_file_ffi(path : XExternString, content : XExternString) = "__moonbit_fs_unstable" "write_string_to_file"

pub fn write_bytes_to_file(path : String, content : Bytes) -> Unit {
  let path = string_to_extern(path)
  let content = byte_array_to_extern(content)
  write_bytes_to_file_ffi(path, content)
}

fn write_bytes_to_file_ffi(path : XExternString, content : XExternByteArray) = "__moonbit_fs_unstable" "write_bytes_to_file"

pub fn path_exists(path : String) -> Bool {
  let path = string_to_extern(path)
  path_exists_ffi(path)
}

fn path_exists_ffi(path : XExternString) -> Bool = "__moonbit_fs_unstable" "path_exists"

pub fn read_dir(path : String) -> Array[String] {
  let path = string_to_extern(path)
  let dirs = read_dir_ffi(path)
  string_array_from_extern(dirs)
}

fn read_dir_ffi(path : XExternString) -> XExternStringArray = "__moonbit_fs_unstable" "read_dir"

pub fn create_dir(path : String) -> Unit {
  let path = string_to_extern(path)
  create_dir_ffi(path)
}

fn create_dir_ffi(path : XExternString) = "__moonbit_fs_unstable" "create_dir"


pub fn is_dir(path : String) -> Bool {
  let path = string_to_extern(path)
  is_dir_ffi(path)
}

fn is_dir_ffi(path : XExternString) -> Bool = "__moonbit_fs_unstable" "is_dir"

pub fn is_file(path : String) -> Bool {
  let path = string_to_extern(path)
  is_file_ffi(path)
}

fn is_file_ffi(path : XExternString) -> Bool = "__moonbit_fs_unstable" "is_file"

pub fn remove_dir(path : String) -> Unit {
  let path = string_to_extern(path)
  remove_dir_ffi(path)
}

fn remove_dir_ffi(path : XExternString) = "__moonbit_fs_unstable" "remove_dir"

pub fn remove_file(path : String) -> Unit {
  let path = string_to_extern(path)
  remove_file_ffi(path)
}

fn remove_file_ffi(path : XExternString) = "__moonbit_fs_unstable" "remove_file"
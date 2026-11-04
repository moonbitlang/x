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
priv type Handler

///|
#cfg(platform="windows")
priv struct OsString(String)

///|
#cfg(not(platform="windows"))
priv struct OsString(Bytes)

///|
#cfg(platform="windows")
fn OsString::from_string(str : String) -> OsString {
  OsString(str)
}

///|
#cfg(not(platform="windows"))
fn OsString::from_string(str : String) -> OsString {
  OsString(@utf8.encode(str) + Bytes::make(1, (0).to_byte()))
}

///|
#cfg(platform="windows")
fn OsString::to_string(self : OsString) -> String {
  self.0
}

///|
#cfg(not(platform="windows"))
fn OsString::to_string(self : OsString) -> String {
  @utf8.decode_lossy(self.0)
}

///|
extern "C" fn is_null(ptr : Handler) -> Int32 = "moonbitlang_x_fs_is_null"

///|
extern "C" fn get_error_message_ffi() -> Bytes = "moonbitlang_x_fs_get_error_message"

///|
extern "C" fn legacy_file_length(handle : FileHandle) -> Int64 = "moonbitlang_x_file_legacy_length"

///|
fn get_error_message() -> String {
  @utf8.decode_lossy(get_error_message_ffi())
}

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let file = open_file(path, ReadOnly, OpenExisting, false, 0o666, NoSync)
  defer file.close()
  // Preserve the legacy seek-to-end/sized-read contract, including /dev/null.
  let size = native_file_result(
    legacy_file_length(file.handle.unwrap()),
    "read \{path}",
  )
  guard size <= 0x7fffffff else { raise IOError("file too large for Bytes") }
  let bytes = file.read_exactly(size.to_int())
  if file.close_result() is Some(message) {
    raise IOError(message)
  }
  bytes
}

///|
fn read_file_to_string_internal(
  path : String,
  encoding~ : String = "utf8",
) -> String raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  @utf8.decode_lossy(read_file_to_bytes_internal(path))
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let file = open_file(path, WriteOnly, CreateOrTruncate, false, 0o666, NoSync)
  defer file.close()
  let handle = file.handle.unwrap()
  // Sequential OS writes preserve the old support for devices and pipes.
  for total = 0; total < content.length(); {
    let n = handle.write(content, total, content.length() - total, -2)
    guard n > 0 else { raise IOError("write made no progress") }
    continue total + n
  }
  if file.close_result() is Some(message) {
    raise IOError(message)
  }
}

///|
fn write_string_to_file_internal(
  path : String,
  content : String,
  encoding~ : String = "utf8",
) -> Unit raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  let bytes = @utf8.encode(content)
  write_bytes_to_file_internal(path, bytes)
}

///|
#borrow(path)
extern "C" fn stat_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_stat_ffi"

///|
fn path_exists_internal(path : String) -> Bool {
  stat_ffi(OsString::from_string(path)) != -1
}

///|
#borrow(path)
extern "C" fn read_dir_ffi(path : OsString) -> Handler = "moonbitlang_x_fs_read_dir_ffi"

///|
fn handler_to_fixed_array(handler : Handler) -> FixedArray[OsString] = "%identity"

///|
fn read_dir_internal(path : String) -> ArrayView[String] raise IOError {
  let res = read_dir_ffi(OsString::from_string(path))
  guard is_null(res) == 0 else { raise IOError(get_error_message()) }
  let files = handler_to_fixed_array(res)
  files.map(OsString::to_string)[:]
}

///|
#borrow(path)
extern "C" fn create_dir_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_create_dir_ffi"

///|
fn create_dir_internal(path : String) -> Unit raise IOError {
  guard create_dir_ffi(OsString::from_string(path)) == 0 else {
    raise IOError(get_error_message())
  }
}

///|
#borrow(path)
extern "C" fn is_dir_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_is_dir_ffi"

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  let res = is_dir_ffi(OsString::from_string(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  res == 1
}

///|
#borrow(path)
extern "C" fn is_file_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_is_file_ffi"

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  let res = is_file_ffi(OsString::from_string(path))
  guard res != -1 else { raise IOError(get_error_message()) }
  res == 1
}

///|
#borrow(path)
extern "C" fn remove_dir_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_remove_dir_ffi"

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  guard remove_dir_ffi(OsString::from_string(path)) == 0 else {
    raise IOError(get_error_message())
  }
}

///|
#borrow(path)
extern "C" fn remove_file_ffi(path : OsString) -> Int32 = "moonbitlang_x_fs_remove_file_ffi"

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  guard remove_file_ffi(OsString::from_string(path)) == 0 else {
    raise IOError(get_error_message())
  }
}

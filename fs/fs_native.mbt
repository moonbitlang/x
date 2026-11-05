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
#borrow(path)
extern "C" fn file_open_ffi(path : OsString, write : Bool) -> Int64 = "moonbitlang_x_file_open"

///|
extern "C" fn is_null(ptr : Handler) -> Int32 = "moonbitlang_x_fs_is_null"

///|
#borrow(buffer)
extern "C" fn file_read_ffi(
  handle : Int64,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
) -> Int64 = "moonbitlang_x_file_read"

///|
#borrow(buffer)
extern "C" fn file_write_ffi(
  handle : Int64,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
) -> Int64 = "moonbitlang_x_file_write"

///|
extern "C" fn get_error_message_ffi() -> Bytes = "moonbitlang_x_fs_get_error_message"

///|
extern "C" fn file_length_ffi(handle : Int64) -> Int64 = "moonbitlang_x_file_length"

///|
extern "C" fn file_close_ffi(handle : Int64) -> Int64 = "moonbitlang_x_file_close"

///|
extern "C" fn file_error_message_ffi(error : Int32) -> OsString = "moonbitlang_x_file_error_message"

///|
fn native_file_result(
  result : Int64,
  operation : String,
) -> Int64 raise IOError {
  guard result >= 0 else {
    let error = (-result).to_int()
    let message = file_error_message_ffi(error)
      .to_string()
      .trim_end(chars="\r\n")
    raise IOError("\{operation}: \{message} (\{error})")
  }
  result
}

///|
fn get_error_message() -> String {
  @utf8.decode_lossy(get_error_message_ffi())
}

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let file = native_file_result(
    file_open_ffi(OsString::from_string(path), false),
    "open \{path}",
  )
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(file)) })
  // Preserve the existing seek-based length, including special-file behavior.
  let length = native_file_result(file_length_ffi(file), "seek \{path}")
  guard length <= MAX_FILE_BYTES.to_int64() else {
    raise IOError("read \{path}: file too large for Bytes")
  }
  let size = length.to_int()
  let bytes = Bytes::make(size, 0)
  for total = 0; total < size; {
    let n = native_file_result(
      file_read_ffi(file, bytes, total, size - total),
      "read \{path}",
    ).to_int()
    guard n > 0 else { raise IOError("read \{path}: unexpected end of file") }
    continue total + n
  }
  closed = true
  ignore(native_file_result(file_close_ffi(file), "close \{path}"))
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
  let file = native_file_result(
    file_open_ffi(OsString::from_string(path), true),
    "open \{path}",
  )
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(file)) })
  for total = 0; total < content.length(); {
    let n = native_file_result(
      file_write_ffi(file, content, total, content.length() - total),
      "write \{path}",
    ).to_int()
    guard n > 0 else { raise IOError("write \{path}: made no progress") }
    continue total + n
  }
  closed = true
  ignore(native_file_result(file_close_ffi(file), "close \{path}"))
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

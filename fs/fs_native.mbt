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
#cfg(platform="windows")
priv struct OsString(String)

///|
#cfg(not(platform="windows"))
priv struct OsString(Bytes)

///|
#cfg(platform="windows")
fn OsString::from_string(str : StringView) -> OsString {
  OsString(str.to_owned())
}

///|
#cfg(not(platform="windows"))
fn OsString::from_string(str : StringView) -> OsString {
  // Native MoonBit Bytes already carry a trailing NUL for C calls.
  OsString(@utf8.encode(str))
}

///|
extern "C" fn file_length_ffi(handle : FileHandle) -> Int64 = "moonbitlang_x_file_legacy_length"

///|
fn FileJob::execute_io(
  self : FileJob,
  context : String,
  retry_eintr~ : Bool = false,
) -> Int32 raise IOError {
  self.execute(context, retry_eintr~) catch {
    err => raise IOError::from_os_error(err)
  }
}

///|
fn native_file_result(
  result : Int64,
  operation : String,
) -> Int64 raise IOError {
  guard result >= 0 else {
    raise IOError::from_os_error(
      @os_error.from_errno((-result).to_int(), context=operation),
    )
  }
  result
}

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let file = open_file_handle(
    path,
    ReadOnly,
    OpenExisting,
    false,
    0o666,
    NoSync,
  ) catch {
    err => raise IOError::from_os_error(err)
  }
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(file)) })
  let length = native_file_result(file_length_ffi(file), "seek \{path}")
  guard length <= MAX_FILE_BYTES.to_int64() else {
    raise IOError("read \{path}: file too large for Bytes")
  }
  let size = length.to_int()
  let buffer : FixedArray[Byte] = FixedArray::make(size, 0)
  for total = 0; total < size; {
    let n = make_native_read_job(
      file,
      buffer,
      total,
      size - total,
      total.to_int64(),
    ).execute_io("read \{path}", retry_eintr=true)
    guard n > 0 else { raise IOError("read \{path}: unexpected end of file") }
    continue total + n
  }
  closed = true
  ignore(native_file_result(file_close_ffi(file), "close \{path}"))
  buffer.unsafe_reinterpret_as_bytes()
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let file = open_file_handle(
    path,
    WriteOnly,
    CreateOrTruncate,
    false,
    0o666,
    NoSync,
  ) catch {
    err => raise IOError::from_os_error(err)
  }
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(file)) })
  // A negative runtime offset writes at the handle's current position.
  for total = 0; total < content.length(); {
    let n = make_native_write_job(
      file,
      content,
      total,
      content.length() - total,
      -1,
    ).execute_io("write \{path}", retry_eintr=true)
    guard n > 0 else { raise IOError("write \{path}: made no progress") }
    continue total + n
  }
  closed = true
  ignore(native_file_result(file_close_ffi(file), "close \{path}"))
}

///|
#cfg(platform="windows")
#borrow(path)
extern "C" fn windows_path_is_dir(path : OsString) -> Int64 = "moonbitlang_x_windows_path_is_dir"

///|
#cfg(platform="windows")
fn native_path_kind(path : String) -> FileKind raise IOError {
  // Keep Win32 attribute semantics, including directory reparse points.
  let is_dir = native_file_result(
    windows_path_is_dir(OsString::from_string(path)),
    "stat \{path}",
  )
  if is_dir != 0 {
    Directory
  } else {
    Regular
  }
}

///|
#cfg(not(platform="windows"))
fn native_path_kind(path : String) -> FileKind raise IOError {
  let fields : FixedArray[Int64] = FixedArray::make(2, 0L)
  let mask = stat_by_path(path, STAT_KIND, true, fields)
  guard (mask & STAT_KIND) != 0 else { return Unknown }
  FileKind::from_stat(fields[1])
}

///|
fn path_exists_internal(path : String) -> Bool {
  let _ = native_path_kind(path) catch { _ => return false }
  true
}

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  native_path_kind(path) is Directory
}

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  native_path_kind(path) is Regular
}

///|
#owned(path)
extern "C" fn make_mkdir_job(path : OsString, permission : Int32) -> FileJob = "moonbit_rt_make_mkdir_job"

///|
#owned(path)
extern "C" fn make_rmdir_job(path : OsString) -> FileJob = "moonbit_rt_make_rmdir_job"

///|
fn create_dir_internal(path : String) -> Unit raise IOError {
  ignore(
    make_mkdir_job(OsString::from_string(path), 0o777).execute_io(
      "mkdir \{path}",
    ),
  )
}

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  ignore(
    make_rmdir_job(OsString::from_string(path)).execute_io("rmdir \{path}"),
  )
}

///|
#cfg(not(platform="windows"))
#owned(path)
extern "C" fn make_remove_job(path : OsString) -> FileJob = "moonbit_rt_make_remove_job"

///|
#cfg(not(platform="windows"))
fn remove_file_internal(path : String) -> Unit raise IOError {
  ignore(
    make_remove_job(OsString::from_string(path)).execute_io("remove \{path}"),
  )
}

///|
#cfg(platform="windows")
#borrow(path)
extern "C" fn windows_remove_file(path : OsString) -> Int64 = "moonbitlang_x_windows_remove_file"

///|
#cfg(platform="windows")
fn remove_file_internal(path : String) -> Unit raise IOError {
  // DeleteFileW rejects directory reparse points as well as ordinary directories.
  ignore(
    native_file_result(
      windows_remove_file(OsString::from_string(path)),
      "remove \{path}",
    ),
  )
}

///|
type DirectoryBuffer = FixedArray[Byte]

///|
#borrow(buffer)
extern "C" fn make_readdir_job(
  dir : FileHandle,
  buffer : FixedArray[Byte],
  len : Int32,
  restart : Bool,
) -> FileJob = "moonbit_rt_make_readdir_job"

///|
#borrow(buffer)
extern "C" fn entry_length(buffer : FixedArray[Byte], offset : Int32) -> Int32 = "moonbit_rt_dir_entry_length"

///|
#borrow(buffer)
extern "C" fn entry_name_offset(
  buffer : FixedArray[Byte],
  offset : Int32,
) -> Int32 = "moonbit_rt_dir_entry_get_name_offset"

///|
#borrow(buffer)
extern "C" fn entry_name_length(
  buffer : FixedArray[Byte],
  offset : Int32,
) -> Int32 = "moonbit_rt_dir_entry_get_name_len"

///|
#cfg(platform="windows")
#borrow(buffer)
extern "C" fn entry_name(
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
) -> String = "moonbit_rt_c_buffer_as_string"

///|
#cfg(not(platform="windows"))
fn entry_name(buffer : FixedArray[Byte], offset : Int32, len : Int32) -> String {
  @utf8.decode_lossy(buffer.unsafe_reinterpret_as_bytes()[offset:offset + len])
}

///|
extern "C" fn native_platform() -> @types.Platform = "moonbit_rt_get_platform"

///|
fn read_dir_internal(path : String) -> ArrayView[String] raise IOError {
  let dir = open_native_handle(
    path,
    ACCESS_LIST_DIRECTORY,
    OpenExisting,
    false,
    0,
    NoSync,
  ) catch {
    err => raise IOError::from_os_error(err)
  }
  defer ignore(file_close_ffi(dir))
  let names = []
  let buffer : DirectoryBuffer = FixedArray::make(DIR_BUFFER_SIZE, 0)
  let platform = native_platform()
  for ;; {
    let job = make_readdir_job(dir, buffer, buffer.length(), false)
    let n = job.execute_io("readdir \{path}", retry_eintr=true)
    if n == 0 {
      break
    }
    append_dir_entries(names, buffer, n, platform)
  }
  names[:]
}

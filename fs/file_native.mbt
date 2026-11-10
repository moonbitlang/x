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
priv struct FileHandle(Int64)

///|
let max_file_position : Int64 = 0x7fffffffffffffff

///|
#borrow(buffer)
extern "C" fn sync_file_read_ffi(
  handle : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int64 = "moonbitlang_x_file_read"

///|
#borrow(buffer)
extern "C" fn sync_file_write_ffi(
  handle : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int64 = "moonbitlang_x_file_write"

///|
extern "C" fn file_size_ffi(handle : FileHandle) -> Int64 = "moonbitlang_x_file_size"

///|
extern "C" fn file_sync_ffi(handle : FileHandle, only_data : Bool) -> Int64 = "moonbitlang_x_file_sync"

///|
extern "C" fn sync_file_close_ffi(handle : FileHandle) -> Int64 = "moonbitlang_x_file_close"

///|
// Stubs capture errno/GetLastError before any cleanup or MoonBit allocation.
fn sync_file_result(result : Int64, operation : String) -> Int64 raise {
  guard result >= 0 else {
    raise OSError((-result).to_int(), context=operation)
  }
  result
}

///|
fn open_file_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise {
  FileHandle(
    sync_file_result(
      file_open_ffi(
        OsString::from_string(path),
        mode,
        create_mode,
        append,
        permission,
        sync,
      ),
      "open \{path}",
    ),
  )
}

///|
fn FileHandle::read_once(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise {
  sync_file_result(
    sync_file_read_ffi(self, buffer, offset, len, position),
    "read",
  ).to_int()
}

///|
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise {
  sync_file_result(
    sync_file_write_ffi(self, buffer, offset, len, position),
    "write",
  ).to_int()
}

///|
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  sync_file_result(file_size_ffi(self), "size")
}

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise {
  ignore(sync_file_result(file_sync_ffi(self, only_data), "sync"))
}

///|
fn FileHandle::close(self : FileHandle) -> Error? {
  let result = sync_file_close_ffi(self)
  if result < 0 {
    Some(OSError((-result).to_int(), context="close"))
  } else {
    None
  }
}

///|
// O_SYNC/O_DSYNC or FILE_FLAG_WRITE_THROUGH already synchronize each write.
fn FileHandle::finish_write(_self : FileHandle) -> Unit {
  ()
}

///|
fn os_error_message(error : Int32) -> String {
  file_error_message_ffi(error).to_string().trim_end(chars="\r\n").to_owned()
}

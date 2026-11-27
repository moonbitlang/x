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
#cfg(not(platform="windows"))
#derive(Eq)
priv struct FileHandle(Int32)

///|
#cfg(platform="windows")
#external
priv type FileHandle

///|
#cfg(platform="windows")
impl Eq for FileHandle with fn equal(self, other) = "%refeq"

///|
let max_file_position : Int64 = 0x7fffffffffffffff

///|
#external
priv type FileJob

///|
extern "C" fn FileJob::run(self : FileJob) -> Unit = "moonbit_rt_run_job"

///|
extern "C" fn FileJob::err(self : FileJob) -> Int32 = "moonbit_rt_job_get_err"

///|
extern "C" fn FileJob::free(self : FileJob) -> Unit = "moonbit_rt_free_job"

///|
extern "C" fn FileJob::ret(self : FileJob) -> Int32 = "moonbit_rt_job_get_ret"

///|
fn FileJob::execute(
  self : FileJob,
  context : String,
  retry_eintr~ : Bool = false,
) -> Int32 raise @os_error.OsError {
  defer self.free()
  for ;; {
    self.run()
    let error = self.err()
    if retry_eintr && !is_windows() && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise @os_error.from_errno(error, context~) }
    break self.ret()
  }
}

///|
#owned(path, fields)
extern "C" fn make_native_open_job(
  parent : FileHandle,
  path : OsString,
  access : Int32,
  create : CreateMode,
  append : Bool,
  sync : SyncMode,
  permission : Int32,
  request : UInt32,
  fields : FixedArray[Int64],
  len : Int32,
) -> FileJob = "moonbit_rt_make_openat_job"

///|
extern "C" fn FileJob::opened_handle(self : FileJob) -> FileHandle = "moonbit_rt_openat_job_get_fd"

///|
fn open_native_handle(
  path : String,
  access : Int32,
  create : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise @os_error.OsError {
  let parent = invalid_parent_fd()
  // Even with an empty request, openat requires space for the stat header.
  let job = make_native_open_job(
    parent,
    OsString::from_string(path),
    access,
    create,
    append,
    sync,
    permission,
    0,
    FixedArray::make(1, 0L),
    8,
  )
  defer job.free()
  for ;; {
    job.run()
    let error = job.err()
    let handle = job.opened_handle()
    // A failed post-open stat closes the fd but leaves its value in the job.
    // Only retry an interrupted open; repeating a successful O_TRUNC loses data.
    if !is_windows() && error == UNIX_EINTR && handle == parent {
      continue
    }
    guard error == 0 else {
      raise @os_error.from_errno(error, context="open \{path}")
    }
    break handle
  }
}

///|
#cfg(not(platform="windows"))
fn open_file_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise @os_error.OsError {
  let access = match mode {
    ReadOnly => 0
    WriteOnly => 1
    ReadWrite => 2
  }
  // The native File API has used O_SYNC for both durability modes on macOS.
  let sync = if sync is Data && native_platform() is MacOS {
    Full
  } else {
    sync
  }
  open_native_handle(path, access, create_mode, append, permission, sync)
}

///|
#cfg(platform="windows")
#borrow(path, error)
extern "C" fn open_windows_file(
  path : OsString,
  mode : Mode,
  create : CreateMode,
  sync : SyncMode,
  error : FixedArray[Int32],
) -> FileHandle = "moonbitlang_x_open_windows_file"

///|
#cfg(platform="windows")
fn open_file_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  _append : Bool,
  _permission : Int32,
  sync : SyncMode,
) -> FileHandle raise @os_error.OsError {
  // Keep Win32 file-only opens and GENERIC_WRITE for truncate + atomic append.
  let error = FixedArray::make(1, 0)
  let handle = open_windows_file(
    OsString::from_string(path),
    mode,
    create_mode,
    sync,
    error,
  )
  if error[0] != 0 {
    raise @os_error.from_errno(error[0], context="open \{path}")
  }
  handle
}

///|
#owned(buffer)
extern "C" fn make_native_read_job(
  handle : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJob = "moonbit_rt_make_read_job"

///|
fn FileHandle::read_once(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise @os_error.OsError {
  make_native_read_job(self, buffer, offset, len, position).execute(
    "read",
    retry_eintr=true,
  )
}

///|
#owned(buffer)
extern "C" fn make_native_write_job(
  handle : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJob = "moonbit_rt_make_write_job"

///|
#cfg(platform="windows")
#borrow(buffer)
extern "C" fn append_windows_file(
  handle : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
) -> Int64 = "moonbitlang_x_append_windows_file"

///|
#cfg(platform="windows")
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise @os_error.OsError {
  if position == APPEND_POSITION {
    let result = append_windows_file(self, buffer, offset, len)
    guard result >= 0 else {
      raise @os_error.from_errno((-result).to_int(), context="write")
    }
    return result.to_int()
  }
  make_native_write_job(self, buffer, offset, len, position).execute(
    "write",
    retry_eintr=true,
  )
}

///|
#cfg(not(platform="windows"))
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise @os_error.OsError {
  make_native_write_job(self, buffer, offset, len, position).execute(
    "write",
    retry_eintr=true,
  )
}

///|
#cfg(not(platform="windows"))
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  let request = STAT_KIND | STAT_SIZE
  let fields : FixedArray[Int64] = FixedArray::make(3, 0L)
  let mask = self.stat(request, fields, context="size")
  guard (mask & request) == request && fields[1] == REGULAR_FILE else {
    raise @os_error.from_errno(22, context="size") // POSIX EINVAL for non-regular files.
  }
  fields[2]
}

///|
#cfg(platform="windows")
extern "C" fn windows_file_size(handle : FileHandle) -> Int64 = "moonbitlang_x_windows_file_size"

///|
#cfg(platform="windows")
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  let result = windows_file_size(self)
  guard result >= 0 else {
    raise @os_error.from_errno((-result).to_int(), context="size")
  }
  result
}

///|
extern "C" fn make_native_sync_job(
  handle : FileHandle,
  only_data : Bool,
) -> FileJob = "moonbit_rt_make_fsync_job"

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise {
  ignore(make_native_sync_job(self, only_data).execute("sync"))
}

///|
extern "C" fn file_close_ffi(handle : FileHandle) -> Int64 = "moonbitlang_x_file_close"

///|
fn FileHandle::close(self : FileHandle) -> Error? {
  let result = file_close_ffi(self)
  if result < 0 {
    Some(@os_error.from_errno((-result).to_int(), context="close"))
  } else {
    None
  }
}

///|
// O_SYNC/O_DSYNC or FILE_FLAG_WRITE_THROUGH already synchronize each write.
fn FileHandle::finish_write(_self : FileHandle) -> Unit {
  ()
}

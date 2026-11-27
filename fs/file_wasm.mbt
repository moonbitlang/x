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
priv struct FileHandle(UInt64)

///|
priv struct FileJob(UInt64)

///|
#unsafe_skip_stub_check
fn file_host_platform() -> @types.Platform = "moonbitlang/async" "runtime/get_platform"

///|
let file_host_is_unix : Bool = file_host_platform() is (Linux | MacOS)

///|
const ACCESS_READ_ONLY : Int32 = 0

///|
const ACCESS_WRITE_ONLY : Int32 = 1

///|
const NO_STAT : UInt32 = 0

///|
/// Every stat result starts with length(u32) and returned-field mask(u32).
const STAT_HEADER_SIZE : Int32 = 8

///|
/// Use the current file position, rather than a positional read/write.
const SEQUENTIAL_POSITION : Int64 = -1

///|
let max_file_position : Int64 = 0x7fffffffffffffff

///|
#unsafe_skip_stub_check
fn FileJob::run(self : FileJob) -> Unit = "moonbitlang/async" "thread_pool/run_job"

///|
#unsafe_skip_stub_check
fn FileJob::free(self : FileJob) -> Unit = "moonbitlang/async" "thread_pool/free_job"

///|
#unsafe_skip_stub_check
fn FileJob::err(self : FileJob) -> Int32 = "moonbitlang/async" "thread_pool/job_get_err"

///|
#unsafe_skip_stub_check
fn FileJob::ret(self : FileJob) -> Int32 = "moonbitlang/async" "thread_pool/job_get_ret"

///|
#unsafe_skip_stub_check
#borrow(path)
fn make_openat_job(
  parent : FileHandle,
  path : String,
  path_len~ : Int32,
  access~ : Int32,
  create~ : CreateMode,
  append~ : Bool,
  sync~ : SyncMode,
  permission~ : Int32,
  stat_request~ : UInt32,
  stat_buf_len~ : Int32,
) -> FileJob = "moonbitlang/async" "thread_pool/make_openat_job"

///|
#unsafe_skip_stub_check
fn FileJob::fd(self : FileJob) -> FileHandle = "moonbitlang/async" "thread_pool/open_job_get_fd"

///|
#unsafe_skip_stub_check
fn make_stat_job(
  handle : FileHandle,
  request~ : UInt32,
  len~ : Int32,
) -> FileJob = "moonbitlang/async" "thread_pool/make_fstatx_job"

///|
#unsafe_skip_stub_check
fn make_read_job(
  handle : FileHandle,
  len : Int32,
  position~ : Int64,
) -> FileJob = "moonbitlang/async" "thread_pool/make_read_job"

///|
#unsafe_skip_stub_check
#borrow(buffer)
fn FileJob::copy_read(
  self : FileJob,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
) -> Unit = "moonbitlang/async" "thread_pool/get_read_result"

///|
#unsafe_skip_stub_check
#borrow(buffer)
fn make_write_job(
  handle : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position~ : Int64,
) -> FileJob = "moonbitlang/async" "thread_pool/make_write_job"

///|
#unsafe_skip_stub_check
fn file_close_ffi(handle : FileHandle) -> Int32 = "moonbitlang/async" "fd_util/close_fd"

///|
#unsafe_skip_stub_check
fn file_errno() -> Int32 = "moonbitlang/async" "os_error/get_errno"

///|
fn file_error(error : Int32, operation : String) -> IOError {
  IOError::from_os_error(@os_error.from_errno(error, context=operation))
}

///|
fn open_wasm_handle(
  path : String,
  access : Int32,
  create~ : CreateMode,
  append~ : Bool,
  sync~ : SyncMode,
  permission~ : Int32,
) -> FileHandle raise @os_error.OsError {
  // A zero stat request skips the post-open metadata query in moonrun.
  let job = make_openat_job(
    invalid_parent_fd(),
    path,
    path_len=path.length(),
    access~,
    create~,
    append~,
    sync~,
    permission~,
    stat_request=NO_STAT,
    stat_buf_len=STAT_HEADER_SIZE,
  )
  defer job.free()
  job.run()
  let error = job.err()
  guard error == 0 else {
    raise @os_error.from_errno(error, context="open \{path}")
  }
  job.fd()
}

///|
fn open_legacy_handle(
  path : String,
  access : Int32,
  create~ : CreateMode = OpenExisting,
) -> FileHandle raise IOError {
  for ;; {
    let handle = open_wasm_handle(
      path,
      access,
      create~,
      append=false,
      sync=NoSync,
      permission=0o666,
    ) catch {
      OsError(_, raw_code=UNIX_EINTR, ..) if file_host_is_unix => continue
      err => raise IOError::from_os_error(err)
    }
    break handle
  }
}

///|
/// Query the opened handle; unsupported metadata must not prevent streaming.
fn FileHandle::size_hint(self : FileHandle) -> Int32? {
  let size = self.size() catch { _ => return None }
  guard size > 0 && size < MAX_FILE_BYTES.to_int64() else { return None }
  Some(size.to_int())
}

///|
/// Adapt File.read_all's size hint, EOF probe, and retained-chunk fallback.
fn FileHandle::read_all(
  self : FileHandle,
  path : String,
  size_hint : Int32?,
) -> Bytes raise IOError {
  read_all_with_hint(
    (buffer, offset) => {
      self.read_once(
        buffer,
        offset,
        buffer.length() - offset,
        SEQUENTIAL_POSITION,
      )
    },
    size_hint,
  ) catch {
    @os_error.OsError(_) as err =>
      raise IOError::from_os_error(err.wrap_context(op => "\{op} \{path}"))
    Failure::Failure(message) => raise IOError("read \{path}: \{message}")
    error => raise IOError("read \{path}: \{error}")
  }
}

///|
fn open_file_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise @os_error.OsError {
  let access = match mode {
    ReadOnly => ACCESS_READ_ONLY
    WriteOnly => ACCESS_WRITE_ONLY
    ReadWrite => 2
  }
  open_wasm_handle(
    path,
    access,
    create=create_mode,
    append~,
    sync~,
    permission~,
  )
}

///|
fn FileHandle::read_once(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise @os_error.OsError {
  for ;; {
    let job = make_read_job(self, len, position~)
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise @os_error.from_errno(error, context="read") }
    let n = job.ret()
    job.copy_read(buffer, offset, n)
    break n
  }
}

///|
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise @os_error.OsError {
  for ;; {
    let job = make_write_job(self, buffer, offset, len, position~)
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise @os_error.from_errno(error, context="write") }
    break job.ret()
  }
}

///|
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  let request = STAT_KIND | STAT_SIZE
  let fields = FixedArray::make(3, 0L)
  let mask = self.stat(request, fields, context="size")
  guard (mask & request) == request && fields[1] == REGULAR_FILE else {
    raise Failure::Failure("size: not a regular file")
  }
  fields[2]
}

///|
#unsafe_skip_stub_check
fn make_sync_job(handle : FileHandle, only_data : Bool) -> FileJob = "moonbitlang/async" "thread_pool/make_fsync_job"

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise {
  let job = make_sync_job(self, only_data)
  defer job.free()
  job.run()
  let error = job.err()
  guard error == 0 else { raise @os_error.from_errno(error, context="sync") }
}

///|
fn FileHandle::close(self : FileHandle) -> Error? {
  if file_close_ffi(self) < 0 {
    Some(@os_error.from_errno(file_errno(), context="close"))
  } else {
    None
  }
}

///|
// The host applies sync flags when opening the file.
fn FileHandle::finish_write(_self : FileHandle) -> Unit {
  ()
}

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let handle = open_legacy_handle(path, ACCESS_READ_ONLY)
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(handle)) })
  let contents = handle.read_all(path, handle.size_hint())
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise file_error(file_errno(), "close \{path}")
  }
  contents
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let handle = open_legacy_handle(
    path,
    ACCESS_WRITE_ONLY,
    create=CreateOrTruncate,
  )
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(handle)) })
  for total = 0; total < content.length(); {
    // Like async's write loop, pass the remaining region without slicing/copying it.
    let n = handle.write(
      content,
      total,
      content.length() - total,
      SEQUENTIAL_POSITION,
    ) catch {
      err =>
        raise IOError::from_os_error(err.wrap_context(op => "\{op} \{path}"))
    }
    guard n > 0 else { raise IOError("write \{path}: made no progress") }
    continue total + n
  }
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise file_error(file_errno(), "close \{path}")
  }
}

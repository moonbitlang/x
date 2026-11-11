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

// ABI declarations follow moonbitlang/async at 6c3c4c886f63318e15450d15a4cd5d3016f09449.
// "moonbitlang/async" is a host import module, not a MoonBit dependency.

///|
priv struct FileHandle(UInt64)

///|
priv struct FileJob(UInt64)

///|
/// runtime/get_platform uses the same tags as async's Platform.
priv enum FileHostPlatform {
  Linux = 0
  MacOS = 1
  Windows = 2
}

///|
#unsafe_skip_stub_check
fn file_host_platform() -> FileHostPlatform = "moonbitlang/async" "runtime/get_platform"

///|
let file_host_is_unix : Bool = match file_host_platform() {
  Linux | MacOS => true
  Windows => false
}

///|
/// EINTR is 4 on both Linux and macOS; Windows error 4 is not EINTR.
const UNIX_EINTR : Int32 = 4

///|
const ACCESS_READ_ONLY : Int32 = 0

///|
const ACCESS_WRITE_ONLY : Int32 = 1

///|
const OPEN_EXISTING : Int32 = 0

///|
const CREATE_OR_TRUNCATE : Int32 = 3

///|
const NO_SYNC : Int32 = 0

///|
const NO_STAT : UInt32 = 0

///|
const STAT_KIND : UInt32 = 1

///|
const STAT_SIZE : UInt32 = 2

///|
/// Every stat result starts with length(u32) and returned-field mask(u32).
const STAT_HEADER_SIZE : Int32 = 8

///|
/// The header followed by kind(i64) and size(i64), in little-endian order.
const STAT_KIND_SIZE_LENGTH : Int32 = 24

///|
const REGULAR_FILE : Int64 = 1

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
fn make_open_job(
  path : String,
  path_len~ : Int32,
  access~ : Int32,
  create~ : Int32,
  append~ : Bool,
  sync~ : Int32,
  permission~ : Int32,
  stat_request~ : UInt32,
  stat_buf_len~ : Int32,
) -> FileJob = "moonbitlang/async" "thread_pool/make_open_stat_job"

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
#borrow(buffer)
fn FileJob::copy_stat(
  self : FileJob,
  buffer : FixedArray[Byte],
  len : Int32,
) -> Unit = "moonbitlang/async" "thread_pool/get_stat_result"

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
priv struct OsErrorText(UInt64)

///|
#unsafe_skip_stub_check
fn errno_to_string(error : Int32) -> OsErrorText = "moonbitlang/async" "os_error/errno_to_string"

///|
#unsafe_skip_stub_check
fn OsErrorText::free(self : OsErrorText) -> Unit = "moonbitlang/async" "os_error/free_errno_str"

///|
#unsafe_skip_stub_check
fn OsErrorText::decoded_length(
  self : OsErrorText,
  offset : Int32,
  len : Int32,
) -> Int32 = "moonbitlang/async" "os_string/decode_len"

///|
#unsafe_skip_stub_check
#borrow(output)
fn OsErrorText::decode(
  self : OsErrorText,
  offset : Int32,
  len : Int32,
  output : String,
  output_len : Int32,
) -> Unit = "moonbitlang/async" "os_string/decode"

///|
/// Decode the host-native error string (UTF-16 on Windows, UTF-8 on Unix).
fn os_error_message(error : Int32) -> String {
  let text = errno_to_string(error)
  defer text.free()
  let nul_terminated = -1
  let len = text.decoded_length(0, nul_terminated)
  let message = String::make(len, '\u{0}')
  text.decode(0, nul_terminated, message, len)
  message.trim_end(chars="\r\n").to_owned()
}

///|
fn file_error(error : Int32, operation : String) -> IOError {
  IOError("\{operation}: \{os_error_message(error)} (\{error})")
}

///|
fn open_handle(path : String, writing : Bool) -> FileHandle raise IOError {
  for ;; {
    let job = make_open_job(
      path,
      path_len=path.length(),
      access=if writing { ACCESS_WRITE_ONLY } else { ACCESS_READ_ONLY },
      create=if writing { CREATE_OR_TRUNCATE } else { OPEN_EXISTING },
      append=false,
      sync=NO_SYNC,
      permission=0o666, // Preserve x/fs's creation permissions, subject to umask.
      stat_request=NO_STAT,
      stat_buf_len=STAT_HEADER_SIZE,
    )
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise file_error(error, "open \{path}") }
    // Claim the descriptor before freeing the job. It has a separate lifetime.
    break job.fd()
  }
}

///|
/// Query the opened handle; unsupported metadata must not prevent streaming.
fn FileHandle::size_hint(self : FileHandle) -> Int32? {
  let request = STAT_KIND | STAT_SIZE
  let job = make_stat_job(self, request~, len=STAT_KIND_SIZE_LENGTH)
  defer job.free()
  job.run()
  guard job.err() == 0 else { return None }
  let stat : FixedArray[Byte] = FixedArray::make(STAT_KIND_SIZE_LENGTH, 0)
  job.copy_stat(stat, stat.length())
  guard stat is [u32le(_), u32le(mask), i64le(kind), i64le(size)] &&
    (mask & request) == request &&
    kind == REGULAR_FILE &&
    size > 0 &&
    size < MAX_FILE_BYTES.to_int64() else {
    return None
  }
  Some(size.to_int())
}

///|
/// Like Reader.read, a single read may return fewer bytes than requested.
fn FileHandle::read(
  self : FileHandle,
  buffer : FixedArray[Byte],
  path : String,
  offset~ : Int32 = 0,
) -> Int32 raise IOError {
  self.read_once(buffer, offset, buffer.length() - offset, SEQUENTIAL_POSITION) catch {
    @os_error.OsError(_, raw_code=error, ..) =>
      raise file_error(error, "read \{path}")
    error => raise IOError("read \{path}: \{error}")
  }
}

///|
/// Adapt File.read_all's size hint, EOF probe, and retained-chunk fallback.
fn FileHandle::read_all(
  self : FileHandle,
  path : String,
  size_hint : Int32?,
) -> Bytes raise IOError {
  read_all_with_hint(
    (buffer, offset) => self.read(buffer, path, offset~),
    size_hint,
  ) catch {
    IOError(message) => raise IOError(message)
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
) -> FileHandle raise {
  let job = make_open_job(
    path,
    path_len=path.length(),
    access=match mode {
      ReadOnly => 0
      WriteOnly => 1
      ReadWrite => 2
    },
    create=match create_mode {
      OpenExisting => 0
      TruncateExisting => 1
      OpenOrCreate => 2
      CreateOrTruncate => 3
      CreateNew => 4
    },
    append~,
    sync=match sync {
      NoSync => 0
      Data => 1
      Full => 2
    },
    permission~,
    stat_request=NO_STAT,
    stat_buf_len=STAT_HEADER_SIZE,
  )
  defer job.free()
  // This job combines open and stat. Retrying the whole job could repeat a
  // successful truncation after a metadata failure; raw-open retry belongs
  // in the host. New APIs therefore propagate an interrupted open job.
  job.run()
  let error = job.err()
  guard error == 0 else {
    raise @os_error.from_errno(error, context="open \{path}")
  }
  job.fd()
}

///|
fn FileHandle::read_once(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise {
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
) -> Int32 raise {
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
  let job = make_stat_job(self, request~, len=STAT_KIND_SIZE_LENGTH)
  defer job.free()
  job.run()
  let error = job.err()
  guard error == 0 else { raise @os_error.from_errno(error, context="size") }
  let stat : FixedArray[Byte] = FixedArray::make(STAT_KIND_SIZE_LENGTH, 0)
  job.copy_stat(stat, stat.length())
  guard stat is [u32le(_), u32le(mask), i64le(kind), i64le(size)] &&
    (mask & request) == request &&
    kind == REGULAR_FILE else {
    raise Failure::Failure("size: not a regular file")
  }
  size
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
  let handle = open_handle(path, false)
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
  let handle = open_handle(path, true)
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
      @os_error.OsError(_, raw_code=error, ..) =>
        raise file_error(error, "write \{path}")
      error => raise IOError("write \{path}: \{error}")
    }
    guard n > 0 else { raise IOError("write \{path}: made no progress") }
    continue total + n
  }
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise file_error(file_errno(), "close \{path}")
  }
}

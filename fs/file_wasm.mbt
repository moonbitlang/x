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
const STREAM_CHUNK_SIZE : Int32 = 4096

///|
const GROWING_FILE_CHUNK_SIZE : Int32 = 65536

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
fn file_error(error : Int32, operation : String) -> IOError {
  let text = errno_to_string(error)
  defer text.free()
  let nul_terminated = -1
  let len = text.decoded_length(0, nul_terminated)
  let message = String::make(len, '\u{0}')
  text.decode(0, nul_terminated, message, len)
  IOError("\{operation}: \{message.trim_end(chars="\r\n")} (\{error})")
}

///|
fn open_handle(path : String, writing : Bool) -> FileHandle raise IOError {
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
  guard error == 0 else { raise file_error(error, "open \{path}") }
  // Claim the descriptor before freeing the job. It has a separate lifetime.
  job.fd()
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
  for ;; {
    let job = make_read_job(
      self,
      buffer.length() - offset,
      position=SEQUENTIAL_POSITION,
    )
    defer job.free()
    job.run()
    let error = job.err()
    // A job is single-use. EINTR makes no progress, so recreate it unchanged.
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise file_error(error, "read \{path}") }
    let n = job.ret()
    job.copy_read(buffer, offset, n)
    break n
  }
}

///|
/// Adapt File.read_all's size hint, EOF probe, and retained-chunk fallback.
fn FileHandle::read_all(
  self : FileHandle,
  path : String,
  size_hint : Int32?,
) -> Bytes raise IOError {
  let chunks : Array[(FixedArray[Byte], Int32)] = []
  let mut total = 0
  if size_hint is Some(size) {
    let buffer : FixedArray[Byte] = FixedArray::make(size, 0)
    let n = self.read(buffer, path)
    if n == 0 {
      return b""
    }
    // A size hint cannot establish EOF, even for a regular file.
    let probe : FixedArray[Byte] = FixedArray::make(1, 0)
    if self.read(probe, path) == 0 {
      // No mutable alias escapes; full-buffer results transfer ownership.
      return buffer.unsafe_reinterpret_as_bytes()[:n].to_owned()
    }
    chunks.push((buffer, n))
    chunks.push((probe, 1))
    total = n + 1
  }
  let chunk_size = if size_hint is Some(_) {
    GROWING_FILE_CHUNK_SIZE
  } else {
    STREAM_CHUNK_SIZE
  }
  let mut buffer : FixedArray[Byte] = FixedArray::make(chunk_size, 0)
  let mut offset = 0
  while self.read(buffer, path, offset~) is n && n > 0 {
    guard n <= MAX_FILE_BYTES - total else {
      raise IOError("read \{path}: file too large for Bytes")
    }
    offset += n
    total += n
    if offset == chunk_size {
      chunks.push((buffer, offset))
      buffer = FixedArray::make(chunk_size, 0)
      offset = 0
    }
  }
  if offset > 0 {
    chunks.push((buffer, offset))
  }
  let result : FixedArray[Byte] = FixedArray::make(total, 0)
  for (chunk, len) in chunks; offset = 0 {
    result.unsafe_blit(offset, chunk, 0, len)
    continue offset + len
  }
  result.unsafe_reinterpret_as_bytes()
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
    let job = make_write_job(
      handle,
      content,
      total,
      content.length() - total,
      position=SEQUENTIAL_POSITION,
    )
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue total
    }
    guard error == 0 else { raise file_error(error, "write \{path}") }
    let n = job.ret()
    guard n > 0 else { raise IOError("write \{path}: made no progress") }
    continue total + n
  }
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise file_error(file_errno(), "close \{path}")
  }
}

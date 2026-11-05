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
  path_len : Int32,
  mode : Int32,
  create_mode : Int32,
  append : Bool,
  sync : Int32,
  permission : Int32,
  stat_request : UInt32,
  stat_buf_len : Int32,
) -> FileJob = "moonbitlang/async" "thread_pool/make_open_stat_job"

///|
#unsafe_skip_stub_check
fn FileJob::fd(self : FileJob) -> FileHandle = "moonbitlang/async" "thread_pool/open_job_get_fd"

///|
#unsafe_skip_stub_check
fn make_read_job(handle : FileHandle, len : Int32, position : Int64) -> FileJob = "moonbitlang/async" "thread_pool/make_read_job"

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
  position : Int64,
) -> FileJob = "moonbitlang/async" "thread_pool/make_write_job"

///|
#unsafe_skip_stub_check
fn file_close_ffi(handle : FileHandle) -> Int32 = "moonbitlang/async" "fd_util/close_fd"

///|
#unsafe_skip_stub_check
fn file_errno() -> Int32 = "moonbitlang/async" "os_error/get_errno"

///|
fn FileJob::execute(self : FileJob, operation : String) -> Unit raise IOError {
  self.run()
  let error = self.err()
  guard error == 0 else { raise IOError("\{operation}: OS error \{error}") }
}

///|
fn open_handle(path : String, writing : Bool) -> FileHandle raise IOError {
  let job = make_open_job(
    path,
    path.length(),
    if writing {
      1
    } else {
      0
    }, // WriteOnly / ReadOnly
    if writing {
      3
    } else {
      0
    }, // CreateOrTruncate / OpenExisting
    false,
    0, // NoSync
    0o666,
    0,
    8,
  )
  defer job.free()
  job.execute("open \{path}")
  // Claim the descriptor before freeing the job. It has a separate lifetime.
  job.fd()
}

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let handle = open_handle(path, false)
  let mut closed = false
  defer (if !closed { ignore(file_close_ffi(handle)) })
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  let output = Buffer()
  // The old host read_file also read nonseekable files until EOF.
  for ;; {
    let job = make_read_job(handle, buffer.length(), -1)
    defer job.free()
    job.execute("read")
    let n = job.ret()
    if n == 0 {
      break
    }
    guard n <= 0x7fffffff - output.length() else {
      raise IOError("file too large for Bytes")
    }
    job.copy_read(buffer, 0, n)
    output.write_bytes(Bytes::from_array(buffer[:n]))
  }
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise IOError("close: OS error \{file_errno()}")
  }
  output.to_bytes()
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
    let job = make_write_job(
      handle,
      content,
      total,
      content.length() - total,
      -1,
    )
    defer job.free()
    job.execute("write")
    let n = job.ret()
    guard n > 0 else { raise IOError("write made no progress") }
    continue total + n
  }
  closed = true
  guard file_close_ffi(handle) == 0 else {
    raise IOError("close: OS error \{file_errno()}")
  }
}

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
  path_len : Int32,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  sync : SyncMode,
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
fn make_stat_job(handle : FileHandle, request : UInt32, len : Int32) -> FileJob = "moonbitlang/async" "thread_pool/make_fstatx_job"

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
fn make_sync_job(handle : FileHandle, only_data : Bool) -> FileJob = "moonbitlang/async" "thread_pool/make_fsync_job"

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
fn open_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise IOError {
  let job = make_open_job(
    path,
    path.length(),
    mode,
    create_mode,
    append,
    sync,
    permission,
    0,
    8,
  )
  defer job.free()
  job.execute("open \{path}")
  // Claim the descriptor before freeing the job. It has a separate lifetime.
  job.fd()
}

///|
fn FileHandle::read(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise IOError {
  let job = make_read_job(self, len, position)
  defer job.free()
  job.execute("read")
  let n = job.ret()
  job.copy_read(buffer, offset, n)
  n
}

///|
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise IOError {
  let job = make_write_job(self, buffer, offset, len, position)
  defer job.free()
  job.execute("write")
  job.ret()
}

///|
fn FileHandle::size(self : FileHandle) -> Int64 raise IOError {
  // Public stat-result ABI: length(u32), mask(u32), requested size(i64 LE).
  let job = make_stat_job(self, 2, 16)
  defer job.free()
  job.execute("size")
  let buffer : FixedArray[Byte] = FixedArray::make(16, 0)
  job.copy_stat(buffer, 16)
  guard buffer is [u32le(_), u32le(mask), i64le(size)] && (mask & 2) != 0 else {
    raise IOError("size: unavailable for this file")
  }
  size
}

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise IOError {
  let job = make_sync_job(self, only_data)
  defer job.free()
  job.execute("sync")
}

///|
fn FileHandle::close(self : FileHandle) -> String? {
  if file_close_ffi(self) < 0 {
    let error = file_errno()
    Some("close: OS error \{error}")
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
  let file = open_file(path, ReadOnly, OpenExisting, false, 0o666, NoSync)
  defer file.close()
  let handle = file.handle.unwrap()
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  let output = Buffer()
  // The old host read_file also read nonseekable files until EOF.
  for ;; {
    let n = handle.read(buffer, 0, buffer.length(), -1)
    if n == 0 {
      break
    }
    guard n <= 0x7fffffff - output.length() else {
      raise IOError("file too large for Bytes")
    }
    output.write_bytes(Bytes::from_array(buffer[:n]))
  }
  if file.close_result() is Some(message) {
    raise IOError(message)
  }
  output.to_bytes()
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let file = open_file(path, WriteOnly, CreateOrTruncate, false, 0o666, NoSync)
  defer file.close()
  let handle = file.handle.unwrap()
  for total = 0; total < content.length(); {
    let n = handle.write(content, total, content.length() - total, -1)
    guard n > 0 else { raise IOError("write made no progress") }
    continue total + n
  }
  if file.close_result() is Some(message) {
    raise IOError(message)
  }
}

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
extern "c" fn native_available_parallelism() -> Int = "moonbit_community_unix_available_parallelism"

///|
#borrow(status)
extern "c" fn native_cwd(status : FixedArray[Int]) -> Bytes = "moonbit_community_unix_cwd"

///|
#borrow(path)
extern "c" fn native_chdir(path : Bytes) -> Int = "moonbit_community_unix_chdir"

///|
#borrow(s)
extern "c" fn native_write_stderr(s : Bytes, len : Int) -> Int = "moonbit_community_unix_write_stderr"

///|
extern "c" fn native_stderr_is_terminal() -> Int = "moonbit_community_unix_stderr_is_terminal"

///|
extern "c" fn native_getpid() -> Int = "moonbit_community_unix_getpid"

///|
#borrow(status)
extern "c" fn native_read_stdin(status : FixedArray[Int]) -> Bytes = "moonbit_community_unix_read_stdin"

///|
extern "c" fn native_monotonic_now_ns() -> Int64 = "moonbit_community_unix_monotonic_now_ns"

///|
fn cstr(s : String) -> Bytes {
  @encoding/utf8.encode(s[:])
}

///|
/// Estimate parallelism from the number of online logical CPUs, falling back to
/// 1 if it cannot be determined. This does not account for process affinity or
/// CPU quotas; callers may need to apply their own concurrency limit.
pub fn available_parallelism() -> Int {
  let count = native_available_parallelism()
  if count > 0 {
    count
  } else {
    1
  }
}

///|
/// Read the monotonic clock in nanoseconds, raising OSError if it is unavailable.
/// Its origin is unspecified; use differences between readings to measure elapsed
/// time. Nanosecond units do not imply nanosecond resolution.
pub fn monotonic_now_ns() -> Int64 raise @os_error.OSError {
  let value = native_monotonic_now_ns()
  if value < 0 {
    @os_error.check_errno("monotonic_now_ns")
  }
  value
}

///|
/// Return the current process identifier.
pub fn getpid() -> Int {
  native_getpid()
}

///|
/// Write UTF-8 text, preserving embedded NUL. Write failures raise OSError.
pub fn write_stderr(text : String) -> Unit raise @os_error.OSError {
  let bytes = cstr(text)
  let code = native_write_stderr(bytes, bytes.length())
  if code != 0 {
    raise OSError(code, context="write_stderr")
  }
}

///|
/// Whether stderr is attached to a terminal. Returns false if it cannot be queried.
pub fn stderr_is_terminal() -> Bool {
  native_stderr_is_terminal() != 0
}

///|
/// Read stdin to EOF. Read failures raise OSError instead of returning partial input.
pub fn read_stdin_bytes() -> Bytes raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let bytes = native_read_stdin(status)
  if status[0] != 0 {
    raise OSError(status[0], context="read_stdin")
  }
  bytes
}

///|
/// Return the current working directory, preserving native path separators.
/// Raise OSError if the directory cannot be determined.
pub fn cwd() -> String raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let path = @encoding/utf8.decode_lossy(native_cwd(status)[:])
  if status[0] != 0 {
    raise OSError(status[0], context="cwd")
  }
  path
}

///|
/// Change the working directory of the current process. This affects subsequent
/// relative-path operations throughout the process. Invalid paths raise OSError.
pub fn chdir(path : String) -> Unit raise @os_error.OSError {
  @ffi.validate_string(path, "chdir")
  let code = native_chdir(cstr(path))
  if code != 0 {
    raise OSError(code, context="chdir: " + path)
  }
}

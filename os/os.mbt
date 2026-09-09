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
extern "c" fn native_os_kind() -> Int = "moonbit_community_unix_os_kind"

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
extern "c" fn native_now_ns() -> Int64 = "moonbit_community_unix_now_ns"

///|
extern "c" fn native_exit(code : Int) -> Unit = "moonbit_community_unix_exit"

///|
fn cstr(s : String) -> Bytes {
  @encoding/utf8.encode(s[:])
}

///|
pub(all) enum OsKind {
  Linux
  Macos
  Windows
} derive(Eq)

///|
pub extend OsKind with Eq::{not_equal, equal}

///|
pub fn os_kind() -> OsKind {
  match native_os_kind() {
    1 => Macos
    2 => Windows
    _ => Linux
  }
}

///|
pub fn available_parallelism() -> Int {
  let count = native_available_parallelism()
  if count > 0 {
    count
  } else {
    1
  }
}

///|
pub fn now_ns() -> Int64 {
  native_now_ns()
}

///|
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
/// Read stdin to EOF and decode UTF-8 lossily. I/O failures raise OSError.
pub fn read_stdin() -> String raise @os_error.OSError {
  @encoding/utf8.decode_lossy(read_stdin_bytes()[:])
}

///|
pub fn args() -> Array[String] {
  @env.args()
}

///|
pub fn getenv(name : String) -> String? {
  @env.get_env_var(name)
}

///|
pub fn getenv_or(name : String, fallback : String) -> String {
  getenv(name).unwrap_or(fallback)
}

///|
pub fn setenv(name : String, value : String) -> Unit {
  @env.set_env_var(name, value)
}

///|
pub fn unsetenv(name : String) -> Unit {
  @env.unset_env_var(name)
}

///|
pub fn cwd() -> String raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let path = @encoding/utf8.decode_lossy(native_cwd(status)[:])
  if status[0] != 0 {
    raise OSError(status[0], context="cwd")
  }
  path
}

///|
pub fn chdir(path : String) -> Unit raise @os_error.OSError {
  @ffi.validate_string(path, "chdir")
  let code = native_chdir(cstr(path))
  if code != 0 {
    raise OSError(code, context="chdir: " + path)
  }
}

///|
pub fn exit(code : Int) -> Unit {
  native_exit(code)
}

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
extern "c" fn native_getpid() -> Int = "moonbit_community_unix_getpid"

///|
#borrow(status)
extern "c" fn native_cwd(status : FixedArray[Int]) -> Bytes = "moonbit_community_unix_cwd"

///|
#borrow(path)
extern "c" fn native_chdir(path : Bytes) -> Int = "moonbit_community_unix_chdir"

///|
/// Return the current process identifier.
pub fn getpid() -> Int {
  native_getpid()
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
  let code = native_chdir(@encoding/utf8.encode(path[:]))
  if code != 0 {
    raise OSError(code, context="chdir: " + path)
  }
}

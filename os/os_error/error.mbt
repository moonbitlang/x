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
/// A native OS error with the same code/context shape as async/os_error.OSError.
/// Codes are errno values on POSIX and GetLastError values on Windows. Use the
/// predicates below to recognize common errors across platforms.
pub(all) suberror OSError {
  OSError(Int, context~ : String)
} derive(ToJson)

///|
#doc(hidden)
#deprecated
pub extend OSError with ToJson::{to_json}

///|
extern "c" fn get_errno() -> Int = "moonbit_unix_get_errno"

///|
/// Raise the current POSIX errno or Windows GetLastError if it is nonzero.
/// Call immediately after a native operation reports failure, before any other
/// work that may overwrite the error. Prepare context before the native call.
/// Keep borrowed arguments alive until after this check (e.g. defer ignore(bytes)).
/// Successful operations may leave a stale error and must not be checked.
pub fn check_errno(context : String) -> Unit raise OSError {
  let code = get_errno()
  if code != 0 {
    raise OSError(code, context~)
  }
}

///|
extern "c" fn native_message(code : Int) -> Bytes = "moonbit_unix_error_message"

///|
fn OSError::message(self : OSError) -> String {
  let OSError(code, context~) = self
  let text = @utf8.decode_lossy(native_message(code)).trim_end(chars="\r\n")
  if text.is_empty() {
    "\{context}: OS error \{code}"
  } else {
    "\{context}: \{text}"
  }
}

///|
pub impl Show for OSError with fn output(self, logger) {
  logger <+ "OSError(\{Repr(self.message())})"
}

///|
#doc(hidden)
#deprecated
pub extend OSError with Show::{to_string, output}

///|
pub impl Debug for OSError with fn to_repr(self) {
  Repr::opaque_("@os_error.OSError", Repr::string(self.message()))
}

///|
#doc(hidden)
#deprecated
pub extend OSError with Debug::{to_repr}

///|
/// No such file or directory (including a missing parent directory on Windows).
#cfg(not(platform="windows"))
pub fn OSError::is_ENOENT(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_ENOENT
}

///|
/// No such file or directory (including a missing parent directory on Windows).
#cfg(platform="windows")
pub fn OSError::is_ENOENT(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_ENOENT || code == @error_code.ERROR_PATH_NOT_FOUND
}

///|
/// The destination already exists.
#cfg(not(platform="windows"))
pub fn OSError::is_EEXIST(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_EEXIST
}

///|
/// The destination already exists.
#cfg(platform="windows")
pub fn OSError::is_EEXIST(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_EEXIST || code == @error_code.ERROR_FILE_EXISTS
}

///|
/// Permission denied.
pub fn OSError::is_EACCES(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_EACCES
}

///|
/// A path component is not a directory.
pub fn OSError::is_ENOTDIR(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_ENOTDIR
}

///|
/// Interrupted system call. Always false on Windows, matching async.
#cfg(not(platform="windows"))
pub fn OSError::is_EINTR(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.EINTR
}

///|
/// Interrupted system call. Always false on Windows, matching async.
#cfg(platform="windows")
pub fn OSError::is_EINTR(_self : OSError) -> Bool {
  false
}

///|
/// Invalid argument, including an embedded NUL in a path or process argument.
pub fn OSError::is_EINVAL(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_EINVAL
}

///|
/// A closed or invalid file descriptor/handle.
pub fn OSError::is_EBADF(self : OSError) -> Bool {
  let OSError(code, ..) = self
  code == @error_code.errno_EBADF
}

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
extern "c" fn native_message(code : Int) -> Bytes = "moonbit_unix_error_message"

///|
extern "c" fn native_matches(code : Int, kind : Int) -> Bool = "moonbit_unix_error_matches"

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
pub impl Debug for OSError with fn to_repr(self) {
  Repr::opaque_("@os_error.OSError", Repr::string(self.message()))
}

///|
/// No such file or directory (including a missing parent directory on Windows).
pub fn OSError::is_ENOENT(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 1)
}

///|
/// The destination already exists.
pub fn OSError::is_EEXIST(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 2)
}

///|
/// Permission denied.
pub fn OSError::is_EACCES(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 3)
}

///|
/// A path component is not a directory.
pub fn OSError::is_ENOTDIR(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 4)
}

///|
/// Interrupted system call. Always false on Windows, matching async.
pub fn OSError::is_EINTR(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 5)
}

///|
/// Invalid argument, including an embedded NUL in a path or process argument.
pub fn OSError::is_EINVAL(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 6)
}

///|
/// A closed or invalid file descriptor/handle.
pub fn OSError::is_EBADF(self : OSError) -> Bool {
  let OSError(code, ..) = self
  native_matches(code, 7)
}

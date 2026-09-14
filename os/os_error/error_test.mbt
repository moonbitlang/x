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
extern "c" fn set_errno(code : Int) -> Unit = "moonbit_unix_test_set_errno"

///|
test "check_errno captures native errors and accepts zero" {
  for code in [2, -1, 0x7FFFFFFF] {
    set_errno(code)
    let err = try @os_error.check_errno("native call") catch {
      err => err
    } noraise {
      _ => fail("expected OSError")
    }
    let @os_error.OSError(actual, context~) = err
    assert_eq(actual, code)
    assert_eq(context, "native call")
  }
  set_errno(0)
  @os_error.check_errno("no error")
}

///|
test "zero and unknown native codes do not match error predicates" {
  for code in [0, -1, 0x7FFFFFFF] {
    let err = @os_error.OSError(code, context="test")
    assert_false(err.is_ENOENT())
    assert_false(err.is_EEXIST())
    assert_false(err.is_EACCES())
    assert_false(err.is_ENOTDIR())
    assert_false(err.is_EINTR())
    assert_false(err.is_EINVAL())
    assert_false(err.is_EBADF())
  }
}

///|
test "unknown error formatting preserves code and context" {
  let err = @os_error.OSError(0x7FFFFFFF, context="read_file: missing")
  let message = err.to_string()
  assert_true(message.contains("read_file: missing: "))
  assert_true(message.contains("2147483647"))
  assert_false(message.contains("\\r"))
  assert_false(message.contains("\\n"))
  // Formatting another error must not overwrite the first error's message.
  @os_error.OSError(-1, context="second").to_string() |> ignore
  assert_eq(err.to_string(), message)
  let @os_error.OSError(code, context~) = err
  assert_eq(code, 0x7FFFFFFF)
  assert_eq(context, "read_file: missing")
}

///|
#cfg(not(platform="windows"))
test "POSIX interrupted calls retain EINTR classification" {
  assert_true(@os_error.OSError(4, context="read").is_EINTR())
  assert_false(@os_error.OSError(5, context="read").is_EACCES())
}

///|
#cfg(platform="windows")
test "Windows predicates recognize alternate native codes" {
  // ERROR_FILE_NOT_FOUND and ERROR_PATH_NOT_FOUND.
  for code in [2, 3] {
    assert_true(@os_error.OSError(code, context="open").is_ENOENT())
  }
  // ERROR_FILE_EXISTS and ERROR_ALREADY_EXISTS.
  for code in [80, 183] {
    assert_true(@os_error.OSError(code, context="create").is_EEXIST())
  }
  assert_true(@os_error.OSError(5, context="open").is_EACCES())
  assert_false(@os_error.OSError(13, context="read").is_EACCES())
  // A POSIX EINTR value does not represent interruption on Windows.
  assert_false(@os_error.OSError(4, context="read").is_EINTR())
}

///|
#cfg(platform="windows")
test "Windows message lookup failure falls back to the original code" {
  let err = @os_error.OSError(0x7FFFFFFF, context="read")
  assert_true(err.to_string().contains("read: OS error 2147483647"))
}

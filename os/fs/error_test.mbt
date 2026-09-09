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
fn capture_error(
  f : () -> Unit raise @os_error.OSError,
) -> @os_error.OSError raise {
  try f() catch {
    err => err
  } noraise {
    _ => fail("expected OSError")
  }
}

///|
test "OS errors retain native codes and useful context" {
  let dir = test_dir("error-codes")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let missing = dir + "/missing"
  let read_error = capture_error(() => read_file(missing) |> ignore)
  let @os_error.OSError(read_code, context~) = read_error
  assert_true(read_code != 0)
  assert_true(read_error.is_ENOENT())
  assert_false(read_error.is_EEXIST())
  assert_true(context.contains(missing))
  // Display uses an escaped representation, including backslashes on Windows.
  assert_true(read_error.to_string().contains("read_file:"))
  let write_error = capture_error(() => {
    write_file(missing, b"x", create_mode=OpenExisting)
  })
  let @os_error.OSError(write_code, ..) = write_error
  assert_eq(write_code, read_code)
  assert_true(capture_error(() => mkdir(dir)).is_EEXIST())
  write_file(missing, b"keep")
  assert_true(
    capture_error(() => write_file(missing, b"lost", create_mode=CreateNew)).is_EEXIST(),
  )
  assert_true(capture_error(() => rmdir(missing)).is_ENOTDIR())
  assert_eq(read_file(missing), b"keep")
}

///|
test "NUL paths fail before operating on their prefix" {
  let dir = test_dir("nul-paths")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let file = dir + "/file"
  write_file(file, b"keep")
  let invalid = file + "\u{0}suffix"
  assert_true(capture_error(() => read_file(invalid) |> ignore).is_EINVAL())
  assert_true(capture_error(() => write_file(invalid, b"lost")).is_EINVAL())
  assert_true(capture_error(() => remove(invalid)).is_EINVAL())
  assert_true(capture_error(() => hardlink(file, invalid)).is_EINVAL())
  assert_true(
    capture_error(() => readdir(dir + "\u{0}suffix") |> ignore).is_EINVAL(),
  )
  assert_true(capture_error(() => @os.chdir(dir + "\u{0}suffix")).is_EINVAL())
  assert_eq(read_file(file), b"keep")
}

///|
test "hardlink never replaces or removes an existing destination" {
  let dir = test_dir("link-contract")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let src = dir + "/source"
  let dst = dir + "/destination"
  write_file(src, b"source")
  hardlink(src, dst)
  write_file(src, b"shared")
  assert_eq(read_file(dst), b"shared")
  assert_true(capture_error(() => hardlink(src, dst)).is_EEXIST())
  assert_true(capture_error(() => hardlink(src, src)).is_EEXIST())
  capture_error(() => hardlink(dir + "/missing", dst)) |> ignore
  assert_eq(read_file(src), b"shared")
  assert_eq(read_file(dst), b"shared")
  // A failed link must also preserve a destination that is an unrelated file.
  remove(dst)
  write_file(dst, b"valuable")
  capture_error(() => hardlink(dir + "/missing", dst)) |> ignore
  assert_eq(read_file(dst), b"valuable")
}

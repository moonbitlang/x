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
#cfg(not(platform="windows"))
#borrow(path, times)
extern "c" fn set_times(path : Bytes, times : FixedArray[Int64]) -> Int = "utimes"

///|
#cfg(not(platform="windows"))
#borrow(path)
extern "c" fn chmod(path : Bytes, permission : Int) -> Int = "chmod"

///|
#cfg(not(platform="windows"))
#borrow(target, path)
extern "c" fn symlink(target : Bytes, path : Bytes) -> Int = "symlink"

///|
#cfg(not(platform="windows"))
#borrow(path)
extern "c" fn mkfifo(path : Bytes, permission : Int) -> Int = "mkfifo"

///|
#cfg(not(platform="windows"))
extern "c" fn getuid() -> Int = "getuid"

///|
#cfg(not(platform="windows"))
test "mtime preserves negative seconds and subsecond precision" {
  let dir = test_dir("timestamps")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/file"
  write_file(path, b"x")
  // Two struct timevals on the supported 64-bit POSIX targets. On macOS,
  // the upper half of each microsecond slot is zero padding.
  let times : FixedArray[Int64] = [-1, 250_000, -1, 250_000]
  assert_eq(set_times(@encoding/utf8.encode(path), times), 0)
  assert_eq(mtime(path), (-1L, 250_000_000))
  // Also exercise seconds that do not fit in an Int.
  times[0] = 2_200_000_000L
  times[1] = 3
  times[2] = 2_200_000_000L
  times[3] = 3
  assert_eq(set_times(@encoding/utf8.encode(path), times), 0)
  assert_eq(mtime(path), (2_200_000_000L, 3000))
}

///|
#cfg(not(platform="windows"))
test "symlink metadata and directory removal do not cross links" {
  let dir = test_dir("symlinks")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  let outside = dir + "/outside"
  let tree = dir + "/tree"
  mkdir(outside, recursive=true)
  mkdir(tree)
  let file = outside + "/file"
  write_file(file, b"keep")
  let old_time : FixedArray[Int64] = [100, 0, 100, 0]
  assert_eq(set_times(@encoding/utf8.encode(file), old_time), 0)
  let file_link = tree + "/file-link"
  assert_eq(symlink(b"../outside/file", @encoding/utf8.encode(file_link)), 0)
  assert_true(kind(file_link) is Regular)
  assert_true(kind(file_link, follow_symlink=false) is SymLink)
  assert_eq(mtime(file_link), (100L, 0))
  assert_true(mtime(file_link, follow_symlink=false) != mtime(file_link))
  assert_eq(file_size(file_link), 4L)
  assert_eq(readlink(file_link), "../outside/file")
  assert_eq(realpath(file_link), realpath(file))
  let dangling = tree + "/dangling"
  assert_eq(symlink(b"missing", @encoding/utf8.encode(dangling)), 0)
  assert_eq(readlink(dangling), "missing")
  assert_false(exists(dangling))
  assert_true(kind(dangling, follow_symlink=false) is SymLink)
  assert_true(mtime(dangling, follow_symlink=false).0 > 0L)
  expect_error("kind", () => kind(dangling) |> ignore)
  expect_error("mtime", () => mtime(dangling) |> ignore)
  assert_true(readdir(tree).contains("dangling"))
  remove(dangling)
  let dir_link = tree + "/dir-link"
  assert_eq(symlink(b"../outside", @encoding/utf8.encode(dir_link)), 0)
  assert_true(kind(dir_link) is Directory)
  expect_error("rmdir", () => rmdir(dir_link))
  expect_error("rmdir", () => rmdir(dir_link + "/", recursive=true))
  rmdir(tree, recursive=true)
  assert_true(read_file(file) == b"keep")
}

///|
#cfg(not(platform="windows"))
test "permission options and probes preserve errors" {
  let dir = test_dir("permissions")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let file = dir + "/file"
  write_file(file, b"keep", permission=0o400)
  assert_true(can_read(file))
  assert_false(can_execute(file))
  expect_error("exists", () => exists(file + "/child") |> ignore)
  expect_error("can_read", () => can_read(file + "/child") |> ignore)
  if getuid() == 0 {
    return // root bypasses ordinary read/write permission checks
  }
  assert_false(can_write(file))
  assert_true(capture_error(() => write_file(file, b"lost")).is_EACCES())
  assert_true(read_file(file, sync_timestamp=true) == b"keep")
  set_executable(file)
  assert_true(can_execute(file))
  assert_true(kind(file) is Regular)
  let parent = dir + "/restricted"
  mkdir(parent, permission=0o500)
  expect_error("write_file", () => write_file(parent + "/denied", b"x"))
  assert_eq(chmod(@encoding/utf8.encode(parent), 0o700), 0)
  write_file(parent + "/child", b"x")
  assert_eq(chmod(@encoding/utf8.encode(parent), 0), 0)
  defer chmod(@encoding/utf8.encode(parent), 0o700) |> ignore
  assert_false(can_read(parent + "/child"))
  assert_false(can_write(parent + "/child"))
  assert_false(can_execute(parent + "/child"))
  expect_error("exists", () => exists(parent + "/child") |> ignore)
  expect_error("readdir", () => readdir(parent) |> ignore)
}

///|
#cfg(not(platform="windows"))
test "kind distinguishes pipes and character devices" {
  let dir = test_dir("kinds")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let fifo = dir + "/pipe"
  assert_eq(mkfifo(@encoding/utf8.encode(fifo), 0o600), 0)
  assert_true(kind(fifo) is Pipe)
  expect_error("file_size", () => file_size(fifo) |> ignore)
  assert_true(kind("/dev/null") is CharDevice)
  remove(fifo)
}

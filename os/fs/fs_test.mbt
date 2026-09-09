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
fn temp_dir() -> String {
  for name in ["TMPDIR", "TEMP", "TMP"] {
    match @os.getenv(name) {
      Some(path) if path != "" => return path
      _ => ()
    }
  }
  "/tmp"
}

///|
fn test_dir(name : String) -> String {
  temp_dir() + "/moonbit-unix-test-" + @os.getpid().to_string() + "-" + name
}

///|
fn expect_error(
  operation : String,
  f : () -> Unit raise @os_error.OSError,
) -> Unit raise {
  try f() catch {
    @os_error.OSError(code, context~) => {
      assert_true(code != 0)
      assert_true(context.has_prefix(operation + ":"))
    }
  } noraise {
    _ => fail("expected OSError from " + operation)
  }
}

///|
test "binary file operations and shared metadata" {
  let dir = test_dir("files")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/value"
  write_file(path, b"one\x00")
  write_file(path, b" two\xff", create_mode=OpenOrCreate, append=true)
  assert_true(read_file(path) == b"one\x00 two\xff")
  assert_eq(file_size(path), 9L)
  assert_true(kind(path) is Regular)
  assert_true(kind(dir) is Directory)
  let (sec, ns) = mtime(path)
  assert_true(sec > 1_000_000_000L && sec < 4_000_000_000L)
  assert_true(ns >= 0 && ns < 1_000_000_000)
  // Accept StringView slices as paths, including non-ASCII names.
  let wrapped = dir + "/路径" + "-ignored"
  let view = wrapped[:wrapped.length() - 8]
  write_file(view, b"slice")
  assert_true(read_file(view) == b"slice")
  assert_true(exists(view))
}

///|
test "creation modes distinguish missing and existing files" {
  let dir = test_dir("create-modes")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/file"
  for mode in ([OpenExisting, TruncateExisting] : Array[CreateMode]) {
    expect_error("write_file", () => write_file(path, b"x", create_mode=mode))
    assert_false(exists(path))
  }
  for mode in ([OpenOrCreate, CreateOrTruncate, CreateNew] : Array[CreateMode]) {
    write_file(path, b"abcd", create_mode=mode)
    assert_true(read_file(path) == b"abcd")
    remove(path)
  }
  write_file(path, b"abcd")
  expect_error("write_file", () => {
    write_file(path, b"lost", create_mode=CreateNew)
  })
  assert_true(read_file(path) == b"abcd")
  write_file(path, b"AB", create_mode=OpenExisting)
  assert_true(read_file(path) == b"ABcd")
  write_file(path, b"XY", create_mode=OpenOrCreate)
  assert_true(read_file(path) == b"XYcd")
  write_file(path, b"12", create_mode=CreateOrTruncate)
  assert_true(read_file(path) == b"12")
  write_file(path, b"", create_mode=TruncateExisting)
  assert_true(read_file(path) == b"")
}

///|
test "append is independent of truncation" {
  let dir = test_dir("append-modes")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/file"
  for mode in ([OpenExisting, OpenOrCreate] : Array[CreateMode]) {
    write_file(path, b"original")
    write_file(path, b"+", create_mode=mode, append=true)
    assert_true(read_file(path) == b"original+")
  }
  for mode in ([TruncateExisting, CreateOrTruncate] : Array[CreateMode]) {
    write_file(path, b"original")
    write_file(path, b"new", create_mode=mode, append=true)
    assert_true(read_file(path) == b"new")
  }
  remove(path)
  write_file(path, b"first", create_mode=CreateNew, append=true)
  expect_error("write_file", () => {
    write_file(path, b"+", create_mode=CreateNew, append=true)
  })
  assert_true(read_file(path) == b"first")
}

///|
test "synchronization modes and timestamp flush preserve binary contents" {
  let dir = test_dir("sync")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/file"
  let data = Bytes::make(131072, b'\xab')
  for sync in ([NoSync, Data, Full] : Array[SyncMode]) {
    write_file(path, data, sync~)
    let before = mtime(path)
    assert_true(read_file(path, sync_timestamp=true) == data)
    assert_eq(mtime(path), before)
    write_file(path, b"\x00", create_mode=OpenExisting, sync~, append=true)
    assert_eq(file_size(path), 131073L)
  }
}

///|
test "directory creation and removal distinguish object kinds" {
  let dir = test_dir("directories")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  let nested = dir + "/parent/child"
  expect_error("mkdir", () => mkdir(nested))
  mkdir(nested, permission=0o700, recursive=true)
  expect_error("mkdir", () => mkdir(nested, recursive=true))
  expect_error("mkdir", () => mkdir(nested))
  let path = nested + "/file"
  write_file(path, b"keep")
  expect_error("mkdir", () => mkdir(path, recursive=true))
  expect_error("mkdir", () => mkdir(path + "/child", recursive=true))
  expect_error("rmdir", () => rmdir(path, recursive=true))
  expect_error("remove", () => remove(nested))
  expect_error("rmdir", () => rmdir(nested))
  assert_true(read_file(path) == b"keep")
  remove(path)
  rmdir(nested)
  expect_error("rmdir", () => rmdir(nested, recursive=true))
  expect_error("remove", () => remove(path))
  remove_all(path) // compatibility extension remains idempotent
  mkdir(nested + "/deep", recursive=true)
  write_file(nested + "/deep/data", b"x")
  rmdir(dir, recursive=true)
  assert_false(exists(dir))
}

///|
test "readdir filtering and sorting" {
  let dir = test_dir("readdir")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  assert_eq(readdir(dir).length(), 0)
  write_file(dir + "/z", b"")
  write_file(dir + "/a", b"")
  write_file(dir + "/.hidden", b"")
  mkdir(dir + "/sub")
  // Like async, use Array::sort's String order (length, then code units).
  assert_eq(readdir(dir, sort=true), ["a", "z", "sub", ".hidden"])
  let special = readdir(dir, include_special=true)
  assert_true(special.contains("."))
  assert_true(special.contains(".."))
  if @os.os_kind() != @os.Windows {
    assert_eq(readdir(dir, include_hidden=false, sort=true), ["a", "z", "sub"])
    assert_eq(
      readdir(dir, include_hidden=false, include_special=true, sort=true),
      ["a", "z", "sub"],
    )
    write_file(dir + "/line\nbreak", b"")
    assert_true(readdir(dir).contains("line\nbreak"))
  }
  expect_error("readdir", () => readdir(dir + "/a") |> ignore)
  expect_error("readdir", () => readdir(dir + "/missing") |> ignore)
}

///|
test "probes and failures do not return false success" {
  let dir = test_dir("errors")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let path = dir + "/missing"
  assert_false(exists(path))
  assert_false(can_read(path))
  assert_false(can_write(path))
  assert_false(can_execute(path))
  expect_error("read_file", () => read_file(path) |> ignore)
  expect_error("mtime", () => mtime(path) |> ignore)
  expect_error("kind", () => kind(path) |> ignore)
  expect_error("file_size", () => file_size(path) |> ignore)
  expect_error("touch", () => touch(path))
  expect_error("realpath", () => realpath(path) |> ignore)
  expect_error("read_file", () => read_file(dir) |> ignore)
  expect_error("write_file", () => write_file(dir, b"no"))
  expect_error("file_size", () => file_size(dir) |> ignore)
  write_file(path, b"content")
  assert_true(can_read(path))
  assert_true(can_write(path))
  assert_true(exists(realpath(path)))
}

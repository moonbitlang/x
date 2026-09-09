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
#cfg(platform="windows")
#borrow(path)
extern "c" fn set_attributes(
  path : FixedArray[UInt16],
  attributes : UInt,
) -> Int = "SetFileAttributesW"

///|
#cfg(platform="windows")
fn wide_path(path : String) -> FixedArray[UInt16] {
  let units = path.code_units()
  FixedArray::makei(units.length() + 1, i => {
    if i == units.length() {
      0
    } else {
      units[i]
    }
  })
}

///|
#cfg(platform="windows")
#borrow(path, target)
extern "c" fn create_symlink(
  path : FixedArray[UInt16],
  target : FixedArray[UInt16],
  flags : UInt,
) -> Byte = "CreateSymbolicLinkW"

///|
#cfg(platform="windows")
#borrow(path, target)
extern "c" fn create_junction_fixture(
  path : FixedArray[UInt16],
  target : FixedArray[UInt16],
  as_volume : Int,
) -> Int = "moon_unix_test_junction"

///|
#cfg(platform="windows")
test "Windows realpath keeps UNC paths absolute and usable" {
  // CI provisions a temporary SMB share. Local Windows runs can supply one.
  guard @os.getenv("MOON_UNIX_TEST_UNC_ROOT") is Some(root) else { return }
  assert_true(root.has_prefix("\\\\"))
  let dir = root + "\\realpath-\{@os.getpid()}-\{@os.now_ns()}"
  mkdir(dir)
  defer (remove_all(dir) catch { _ => () })
  let file = dir + "\\hello \u{4e16}\u{754c}.txt"
  write_file(file, b"UNC path")
  let resolved = realpath(file)
  // Match async/fs: turn the extended UNC form into a regular UNC path.
  assert_true(resolved.has_prefix("\\\\"))
  assert_false(resolved.has_prefix("\\\\?\\"))
  assert_eq(read_file(resolved), b"UNC path")
  assert_eq(realpath("\\\\?\\UNC\\" + file[2:].to_owned()), resolved)
  let resolved_dir = realpath(dir)
  assert_eq(readdir(resolved_dir), ["hello \u{4e16}\u{754c}.txt"])
  assert_eq(
    read_file(resolved_dir + "\\hello \u{4e16}\u{754c}.txt"),
    b"UNC path",
  )
}

///|
#cfg(platform="windows")
test "Windows readlink uses the target instead of the junction display name" {
  let dir = test_dir("junction-target")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let target = dir + "/destination"
  mkdir(target)
  write_file(target + "/value", b"target")
  let absolute = realpath(target)
  let link = dir + "/junction"
  mkdir(link)
  assert_eq(create_junction_fixture(wide_path(link), wide_path(absolute), 0), 0)
  assert_eq(readlink(link), "\\\\?\\" + absolute)
  assert_eq(readdir(readlink(link)), ["value"])
  assert_eq(read_file(link + "/value"), b"target")
  let volume = dir + "/volume"
  mkdir(volume)
  assert_eq(
    create_junction_fixture(wide_path(volume), wide_path(absolute), 1),
    0,
  )
  assert_true(readlink(volume).has_prefix("\\\\?\\Volume{"))
  // The volume target must remain usable, including when appending a child path.
  assert_eq(
    read_file(readlink(volume) + absolute[3:].to_owned() + "\\value"),
    b"target",
  )
}

///|
#cfg(platform="windows")
test "Windows readlink preserves relative and dangling targets" {
  let dir = test_dir("link-targets")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let link = dir + "/link"
  // Windows 10+: allow unprivileged creation when developer mode permits it.
  // Hosted Windows CI also grants the symbolic-link privilege.
  assert_true(
    create_symlink(wide_path(link), wide_path("missing.txt"), 2) != b'\x00',
  )
  assert_eq(readlink(link), "missing.txt")
  assert_false(exists(link))
  write_file(dir + "/missing.txt", b"target")
  assert_eq(readlink(link), "missing.txt")
  assert_eq(read_file(link), b"target")
  capture_error(() => readlink(dir + "/missing.txt") |> ignore) |> ignore
}

///|
#cfg(platform="windows")
test "Windows hidden attributes and read-only files" {
  let dir = test_dir("attributes")
  remove_all(dir)
  defer (remove_all(dir) catch { _ => () })
  mkdir(dir)
  let file = dir + "/hidden"
  write_file(file, b"keep")
  let path = wide_path(file)
  assert_true(set_attributes(path, 0x2) != 0) // FILE_ATTRIBUTE_HIDDEN
  defer set_attributes(path, 0x80) |> ignore // FILE_ATTRIBUTE_NORMAL
  assert_true(readdir(dir).contains("hidden"))
  assert_false(readdir(dir, include_hidden=false).contains("hidden"))
  write_file(dir + "/.dotfile", b"dot")
  assert_true(readdir(dir, include_hidden=false).contains(".dotfile"))
  assert_true(set_attributes(path, 0x1) != 0) // FILE_ATTRIBUTE_READONLY
  assert_true(exists(file))
  assert_true(can_read(file))
  assert_false(can_write(file))
  assert_true(read_file(file) == b"keep")
  expect_error("write_file", () => write_file(file, b"lost"))
  // FlushFileBuffers requires write access even for timestamp synchronization.
  expect_error("read_file", () => read_file(file, sync_timestamp=true) |> ignore)
}

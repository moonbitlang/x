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
test "path metadata queries" {
  let dir = file_test_path()
  @fs.create_dir(dir)
  defer @fs.remove_dir(dir)
  let path = dir + "/月🌙"
  @fs.write_bytes_to_file(path, b"")
  defer @fs.remove_file(path)
  debug_inspect(@fs.kind(path), content="Regular")
  assert_eq(@fs.file_size(path), 0L)
  debug_inspect(@fs.kind(dir), content="Directory")
  @test.assert_raise(() => @fs.file_size(dir))
  let id = @fs.identity(path)
  if id is Some(a) && @fs.identity(dir) is Some(b) {
    assert_true(a != b)
  } else if @env.get_env_var("OS_PLATFORM") == Some("windows-latest") {
    fail("expected file and directory identities on the runner's NTFS volume")
  }
  @fs.write_string_to_file(path, "Moon")
  let wrapped = "[" + path + "]"
  let view = wrapped[1:wrapped.length() - 1]
  assert_eq(@fs.file_size(view), 4L)
  assert_true(@fs.identity(view, follow_symlink=false) == id)
  for t in [@fs.atime(view), @fs.mtime(view), @fs.ctime(view)] {
    assert_true(t.sec() > 0 && t.nsec() >= 0 && t.nsec() < 1_000_000_000)
  }
}

///|
test "metadata of an open file survives removal of its path" {
  let path = file_test_path()
  @fs.write_file(path, b"data")
  defer (if @fs.path_exists(path) { @fs.remove_file(path) })
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let id = @fs.identity(path)
  let mtime = @fs.mtime(path)
  assert_true(file.atime() == @fs.atime(path))
  assert_true(file.ctime() == @fs.ctime(path))
  @fs.remove_file(path)
  debug_inspect(file.kind(), content="Regular")
  assert_true(file.identity() == id)
  assert_true(file.mtime() == mtime)
}

///|
test "metadata queries reject missing paths and embedded NULs" {
  let path = file_test_path()
  @test.assert_raise(() => @fs.identity(path))
  @fs.write_bytes_to_file(path, b"present")
  defer @fs.remove_file(path)
  @test.assert_raise(() => @fs.kind(path + "\u0000suffix"))
}

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(target, path)
extern "C" fn posix_link(target : Bytes, path : Bytes) -> Int32 = "link"

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(target, path)
extern "C" fn posix_symlink(target : Bytes, path : Bytes) -> Int32 = "symlink"

///|
#cfg(all(target="native", not(platform="windows")))
test "metadata queries follow symlinks and preserve hard-link identity" {
  let path = file_test_path()
  let hard = path + ".hard"
  let sym = path + ".sym"
  @fs.write_bytes_to_file(path, b"abc")
  defer (@fs.remove_file(path) catch { _ => () })
  let target = @encoding.encode(UTF8, path)
  assert_eq(posix_link(target, @encoding.encode(UTF8, hard)), 0)
  defer @fs.remove_file(hard)
  assert_eq(posix_symlink(target, @encoding.encode(UTF8, sym)), 0)
  defer @fs.remove_file(sym)
  guard @fs.identity(path) is Some(id) else { fail("missing POSIX identity") }
  assert_true(@fs.identity(hard) == Some(id))
  assert_true(@fs.identity(sym) == Some(id))
  debug_inspect(@fs.kind(sym), content="Regular")
  debug_inspect(@fs.kind(sym, follow_symlink=false), content="SymLink")
  assert_eq(@fs.file_size(sym), 3L)
  guard @fs.identity(sym, follow_symlink=false) is Some(link_id) else {
    fail("missing symlink identity")
  }
  assert_true(link_id != id)
  @fs.remove_file(path)
  @test.assert_raise(() => @fs.mtime(sym))
  ignore(@fs.mtime(sym, follow_symlink=false))
  assert_true(@fs.identity(sym, follow_symlink=false) == Some(link_id))
  @fs.write_bytes_to_file(path, b"abc")
  guard @fs.identity(path) is Some(new_id) else {
    fail("missing replacement identity")
  }
  assert_true(new_id != id)
}

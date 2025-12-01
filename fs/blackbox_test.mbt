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
test "write_and_read" {
  let path_1 = "./fs/test_1.txt"
  let path_2 = "./fs/test_2.txt"
  let content_1 = "Hello, World"
  let content_2 = "Hello, MoonBit"
  @fs.write_bytes_to_file(path_1, @encoding.encode(UTF16, content_1))
  let res_1 = @fs.read_file_to_bytes(path_1)
  inspect(res_1.to_unchecked_string(), content=content_1)
  @fs.write_string_to_file(path_2, content_2)
  let res_2 = @fs.read_file_to_string(path_2)
  inspect(res_2, content=content_2)
}

///|
test "read_dir" {
  let path = "./fs"
  let files = @fs.read_dir(path)
  files.sort()
  inspect(
    files,
    content=(
      #|["fs.mbt", "fs_js.mbt", "test_1.txt", "test_2.txt", ".hidden_dir", "example_dir", "fs_native.c", "fs_wasm.mbt", "fs_native.mbt", "moon.pkg.json", "blackbox_test.mbt", "pkg.generated.mbti"]
    ),
  )
}

///|
test "create_dir_and_remove_dir" {
  let path = "./fs/test_dir"
  assert_false(@fs.path_exists(path))
  @fs.create_dir(path)
  assert_true(@fs.path_exists(path))
  assert_true(@fs.is_dir(path))
  assert_false(@fs.is_file(path))
  @fs.remove_dir(path)
  assert_false(@fs.path_exists(path))
}

///|
test "stat" {
  let path = "./fs/stat_test.txt"
  // Ensure cleanup if previous run failed
  if @fs.path_exists(path) {
    @fs.remove_file(path)
  }
  let content = "12345"
  @fs.write_string_to_file(path, content)
  let stats = @fs.stats(path)
  // println(stats)

  // Basic Type and Size
  inspect(stats.size, content="5")

  // Time fields check (sanity check: should be non-zero)
  assert_true(stats.atime_sec > 0L)
  assert_true(stats.mtime_sec > 0L)
  assert_true(stats.ctime_sec > 0L)

  // Metadata checks
  assert_true(stats.nlink >= 1UL)

  // Mode check: Verify it's a regular file (S_IFREG is 0o100000)
  // We mask with S_IFMT (0o170000) to get the file type bits
  let is_reg = (stats.mode & 0o170000U) == 0o100000U
  assert_true(is_reg)

  // UID/GID should be readable (printing them to ensure they are valid numbers)
  // Note: specific values depend on the environment, so we just check they exist
  inspect(stats.uid >= 0U, content="true")
  inspect(stats.gid >= 0U, content="true")
  @fs.remove_file(path)
}

// Copyright 2024 International Digital Economy Academy
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



test "write_and_read" {
  let path = "1.txt"
  @fs.write_string_to_file(
    path="1.txt",
    content=
      #|target/
      #|.mooncakes/
      #|
    ,
  )
  assert_true!(@fs.path_exists(~path))
  let byte = @fs.read_file_to_bytes!(~path).iter().map(fn(x) { x.to_uint() })
  inspect!(
    byte,
    content="[116, 97, 114, 103, 101, 116, 47, 10, 46, 109, 111, 111, 110, 99, 97, 107, 101, 115, 47, 10]",
  )
  @fs.remove_file!(~path)
  assert_false!(@fs.path_exists(~path))

  let bytes = Bytes::from_array([65, 97].map(fn(x) { x.to_byte() }))
  @fs.write_bytes_to_file(~path, content=bytes)
  assert_true!(@fs.path_exists(~path))
  let content = @fs.read_file_to_string!(~path)
  inspect!(content, content="Aa")
  @fs.remove_file!(~path)
  assert_false!(@fs.path_exists(~path))
}

test "path_exist" {
  // dir exist
  assert_true!(@fs.path_exists(path=".github"))
  // dir don't exist
  assert_false!(@fs.path_exists(path="no_exist"))

  // file exist
  assert_true!(@fs.path_exists(path=".gitignore"))

  // file don't exist
  assert_false!(@fs.path_exists(path="no_exist.txt"))
}

test "create_and_remove_dir" {
  @fs.create_dir(path="hello/1/12.txt")
  assert_true!(@fs.path_exists(path="hello/1/12.txt"))
  @fs.remove_dir!(path="hello")
  assert_false!(@fs.path_exists(path="hello"))
}

test "read_dir" {
  let dir_content = @fs.read_dir!(path=".")..sort()
  inspect!(
    dir_content,
    content=
      #|["fs", "num", ".git", "time", "uuid", "json5", "stack", "crypto", "target", ".github", "README.md", ".gitignore", ".mooncakes", "_typos.toml", "moon.mod.json", "licenserc.toml"]
    ,
  )
}

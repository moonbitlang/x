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

///|
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
  assert_true!(@fs.path_exists(path~))
  let byte = @fs.read_file_to_bytes!(path~)
  inspect!(
    byte,
    content=
      #|b"\x74\x61\x72\x67\x65\x74\x2f\x0a\x2e\x6d\x6f\x6f\x6e\x63\x61\x6b\x65\x73\x2f\x0a"
    ,
  )
  @fs.remove_file!(path~)
  assert_false!(@fs.path_exists(path~))
  try {
    @fs.read_file_to_string!(path~) |> ignore
  } catch {
    @fs.IOError::NotFound(_) as e =>
      inspect!(e, content="`1.txt` does not exist")
    _ => return
  }
  let bytes = Bytes::from_array([65, 97].map(fn(x) { x.to_byte() }))
  @fs.write_bytes_to_file(path~, content=bytes)
  assert_true!(@fs.path_exists(path~))
  let content = @fs.read_file_to_string!(path~)
  inspect!(content, content="Aa")
  @fs.remove_file!(path~)
  assert_false!(@fs.path_exists(path~))
  try {
    @fs.remove_file!(path~) |> ignore
  } catch {
    @fs.IOError::NotFound(_) as e =>
      inspect!(e, content="`1.txt` does not exist")
    _ => return
  }
}

///|
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

///|
test "create_and_remove_dir" {
  @fs.create_dir(path="hello")
  assert_true!(@fs.path_exists(path="hello"))
  assert_true!(@fs.is_dir!(path="hello"))
  assert_false!(@fs.is_file!(path="hello"))
  @fs.remove_dir!(path="hello")
  assert_false!(@fs.path_exists(path="hello"))
  try {
    @fs.remove_dir!(path="hello") |> ignore
  } catch {
    @fs.IOError::NotFound(_) as e =>
      inspect!(e, content="`hello` does not exist")
    _ => return
  }
}

///|
test "read_dir" {
  let dir_content = @fs.read_dir!(path="./fs")..sort()
  inspect!(
    dir_content,
    content=
      #|["fs.mbt", "fs.mbti", "internal", "fs_test.mbt", "moon.pkg.json"]
    ,
  )
  try {
    @fs.read_dir!(path="fasd") |> ignore
  } catch {
    @fs.IOError::NotFound(_) as e =>
      inspect!(e, content="`fasd` does not exist")
    _ => return
  }
}

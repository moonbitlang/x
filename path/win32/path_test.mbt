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
test "basename/dirname" {
  inspect(basename("a\\b"), content="b")
  inspect(dirname("a\\b"), content="a")
  inspect(basename("a\\b\\"))
  inspect(dirname("a\\b\\"), content="a\\b")
}

///|
test "extname" {
  inspect(extname("project\\main.mbt.md"), content=".md")
  inspect(extname("project\\"), content="")
}

///|
test "is_absolute" {
  // absolute path cases
  //
  // verbatim symlink 
  @json.inspect(is_absolute("\\\\?\\GLOBALROOT\\file"), content=true)
  // verbatim unc 
  @json.inspect(is_absolute("\\\\?\\UNC\\server\\share\\file"), content=true)
  // verbatim volume letter
  @json.inspect(is_absolute("\\\\?\\C:\\file"), content=true)
  // verbatim volume guid 
  @json.inspect(
    is_absolute("\\\\?\\Volume{12345678-1234-1234-1234-1234567890ab}\\file"),
    content=true,
  )
  // device namespace
  @json.inspect(is_absolute("\\\\.\\COM56"), content=true)
  // unc 
  @json.inspect(is_absolute("\\\\server\\share\\file"), content=true)
  // volume letter root 
  @json.inspect(is_absolute("C:\\"), content=true)
  // relative path cases
  // 
  // volume letter relative path
  @json.inspect(is_absolute("C:folder\\file"), content=false)
  @json.inspect(is_absolute("Users\\user"), content=false)
  @json.inspect(is_absolute(""), content=false)
}

///|
test "join" {
  inspect(join("a", "\\b"), content="\\b")
  inspect(join("a\\", "b"), content="a\\b")
  inspect(join("a", "b"), content="a\\b")
}

///|
test "relative" {
  let from = "C:\\Users\\user_name"
  let to = "C:\\Users\\user_name\\proj_a"
  inspect(relative(from, to), content="proj_a")
  let from = "C:\\Users\\user_name\\proj_a"
  let to = "C:\\Users\\user_name"
  inspect(relative(from, to), content="..")
  let from = "C:\\Users\\user_name"
  let to = "C:\\Users\\user_name"
  inspect(relative(from, to), content="")
  let from = "C:\\Users\\user_name\\proj_a"
  let to = "C:\\Users\\user_name\\proj_b"
  inspect(relative(from, to), content="..\\proj_b")
}

///|
test "normalize" {
  inspect(normalize("a\\.\\b\\..\\c\\"), content="a\\c")
  inspect(normalize("\\a\\b\\..\\..\\c\\."), content="\\c")
  inspect(normalize("a\\b\\c\\.."), content="a\\b")
}

///|
test "resolve" {
  inspect(resolve("\\a\\..\\b\\c"), content="\\b\\c")
  inspect(resolve("\\a\\b\\c\\..\\..\\.."), content="\\")
}

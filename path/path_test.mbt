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
test "debug" {
  let path : @path.Path = "a/b"
  debug_inspect(path, content="Path(\"a/b\")")
}

///|
test "Path::to_string" {
  let path : @path.Path = "a/b"
  inspect(path.to_string(), content="a/b")
}

///|
test "join_raw dispatch preserves components on the host platform" {
  assert_eq(@path.Path::join_raw("", "").to_string(), "")
  assert_eq(@path.Path::join_raw("a//../b/", "").to_string(), "a//../b/")
  assert_eq(@path.Path::join_raw("", "a//../b/").to_string(), "a//../b/")
  assert_eq(@path.Path::join_raw("a/", "b").to_string(), "a/b")
  if @path.sep == '/' {
    assert_eq(
      @path.Path::join_raw("link", "../file").to_string(),
      "link/../file",
    )
    assert_eq(@path.Path::join_raw("C:", "file").to_string(), "C:/file")
  } else {
    assert_eq(
      @path.Path::join_raw("link", "..\\file").to_string(),
      "link\\..\\file",
    )
    assert_eq(@path.Path::join_raw("C:", "file").to_string(), "C:\\file")
  }
}

///|
test "node-compatible top-level dispatch smoke" {
  if @path.sep == '/' {
    inspect(@path.Path::join("a", "/b"), content="a/b")
    inspect(@path.Path::normalize(""), content=".")
    inspect(@path.Path::extname(".hidden"), content="")
  } else {
    inspect(@path.Path::join("a", "\\b"), content="a\\b")
    inspect(@path.Path::normalize(""), content=".")
    inspect(@path.Path::extname(".hidden"), content="")
  }
}

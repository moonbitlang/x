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
  inspect(basename("a/b"), content="b")
  inspect(dirname("a/b"), content="a")
  inspect(basename("a/b/"))
  inspect(dirname("a/b/"), content="a/b")
}

///|
test "extname" {
  inspect(extname("project/main.mbt.md"), content=".md")
  inspect(extname("project/"), content="")
}

///|
test "is_absolute" {
  @json.inspect(is_absolute("/home/user"), content=true)
  @json.inspect(is_absolute("home/user"), content=false)
  @json.inspect(is_absolute(""), content=false)
}

///|
test "join" {
  inspect(join("a", "/b"), content="/b")
  inspect(join("a/", "b"), content="a/b")
  inspect(join("a", "b"), content="a/b")
}

///|
test "relative" {
  let from = "/home/user_name"
  let to = "/home/user_name/proj_a"
  inspect(relative(from, to), content="proj_a")
  let from = "/home/user_name/proj_a"
  let to = "/home/user_name"
  inspect(relative(from, to), content="..")
  let from = "/home/user_name"
  let to = "/home/user_name"
  inspect(relative(from, to), content="")
  let from = "/home/user_name/proj_a"
  let to = "/home/user_name/proj_b"
  inspect(relative(from, to), content="../proj_b")
}

///|
test "normalize" {
  inspect(normalize("a/./b/../c/"), content="a/c")
  inspect(normalize("/a/b/../../c/."), content="/c")
  inspect(normalize("a/b/c/.."), content="a/b")
}

///|
test "resolve" {
  inspect(resolve("/a/../b/c"), content="/b/c")
  inspect(resolve("/a/b/c/../../.."), content="/")
}

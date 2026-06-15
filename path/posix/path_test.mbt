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
  debug_inspect(Path::join("a", "b"), content="Path(\"a/b\")")
}

///|
test "basename node fixtures" {
  inspect(Path::basename(""), content="")
  inspect(Path::basename("/"), content="")
  inspect(Path::basename("//"), content="")
  inspect(Path::basename("///"), content="")
  inspect(Path::basename("a"), content="a")
  inspect(Path::basename("a/"), content="a")
  inspect(Path::basename("a//"), content="a")
  inspect(Path::basename("file.txt/"), content="file.txt")
  inspect(Path::basename("/path/file.txt/"), content="file.txt")
  inspect(Path::basename("/a//b//c/"), content="c")
  inspect(Path::basename("./a"), content="a")
  inspect(Path::basename("../a"), content="a")
  inspect(Path::basename("a/."), content=".")
  inspect(Path::basename("a/.."), content="..")
}

///|
test "dirname node fixtures" {
  inspect(Path::dirname(""), content=".")
  inspect(Path::dirname("a"), content=".")
  inspect(Path::dirname("a/"), content=".")
  inspect(Path::dirname("a//"), content=".")
  inspect(Path::dirname("/"), content="/")
  inspect(Path::dirname("//"), content="/")
  inspect(Path::dirname("///"), content="/")
  inspect(Path::dirname("////"), content="/")
  inspect(Path::dirname("/a"), content="/")
  inspect(Path::dirname("//a"), content="//")
  inspect(Path::dirname("///a"), content="//")
  inspect(Path::dirname("./a"), content=".")
  inspect(Path::dirname("../a"), content="..")
  inspect(Path::dirname("a/."), content="a")
  inspect(Path::dirname("a/.."), content="a")
  inspect(Path::dirname("a//b"), content="a/")
  inspect(Path::dirname("a///b"), content="a//")
  inspect(Path::dirname("/a//b//c"), content="/a//b/")
  inspect(Path::dirname("/a//b//c/"), content="/a//b/")
}

///|
test "extname node dotfile fixtures" {
  inspect(Path::extname(""), content="")
  inspect(Path::extname("file"), content="")
  inspect(Path::extname("/path/file"), content="")
  inspect(Path::extname("project/main.mbt.md"), content=".md")
  inspect(Path::extname("file.tar.gz"), content=".gz")
  inspect(Path::extname("file.c++"), content=".c++")
  inspect(Path::extname("file.123"), content=".123")
  inspect(Path::extname("file.-"), content=".-")
  inspect(Path::extname(".hidden"), content="")
  inspect(Path::extname("/path/.hidden"), content="")
  inspect(Path::extname(".hidden.txt"), content=".txt")
  inspect(Path::extname("/path/.hidden.txt"), content=".txt")
  inspect(Path::extname("."), content="")
  inspect(Path::extname(".."), content="")
  inspect(Path::extname("./file"), content="")
  inspect(Path::extname("../file"), content="")
  inspect(Path::extname("/a/."), content="")
  inspect(Path::extname("/a/.."), content="")
  inspect(Path::extname(".txt"), content="")
  inspect(Path::extname("a.b.c"), content=".c")
  inspect(Path::extname("a."), content=".")
  inspect(Path::extname("/path/a."), content=".")
  inspect(Path::extname("file.txt/"), content=".txt")
  inspect(Path::extname("/path/file.txt/"), content=".txt")
}

///|
test "is_absolute edge cases" {
  json_inspect(Path::is_absolute(""), content=false)
  json_inspect(Path::is_absolute(" "), content=false)
  json_inspect(Path::is_absolute("  /"), content=false)
  json_inspect(Path::is_absolute("/"), content=true)
  json_inspect(Path::is_absolute("//"), content=true)
  json_inspect(Path::is_absolute("///"), content=true)
  json_inspect(Path::is_absolute("/a"), content=true)
  json_inspect(Path::is_absolute("/a/b"), content=true)
  json_inspect(Path::is_absolute("a"), content=false)
  json_inspect(Path::is_absolute("./a"), content=false)
  json_inspect(Path::is_absolute("../a"), content=false)
  json_inspect(Path::is_absolute("a/b"), content=false)
  json_inspect(Path::is_absolute("a/../b"), content=false)
  json_inspect(Path::is_absolute("."), content=false)
  json_inspect(Path::is_absolute(".."), content=false)
  json_inspect(Path::is_absolute("./"), content=false)
  json_inspect(Path::is_absolute("../"), content=false)
  json_inspect(Path::is_absolute("/."), content=true)
  json_inspect(Path::is_absolute("/.."), content=true)
}

///|
test "join node fixtures" {
  inspect(Path::join("a", "b"), content="a/b")
  inspect(Path::join("a", "/b"), content="a/b")
  inspect(Path::join("/a", "/b"), content="/a/b")
  inspect(Path::join("a", "../b"), content="b")
  inspect(Path::join("a", "./b"), content="a/b")
  inspect(Path::join("./a", "b"), content="a/b")
  inspect(Path::join("../a", "b"), content="../a/b")
  inspect(Path::join("", ""), content=".")
  inspect(Path::join("a", ""), content="a")
  inspect(Path::join("", "b"), content="b")
  inspect(Path::join("", "/abs"), content="/abs")
  inspect(Path::join("a//", "b"), content="a/b")
  inspect(Path::join("a///", "b"), content="a/b")
  inspect(Path::join("a//b", "c"), content="a/b/c")
  inspect(Path::join("a", "b//c"), content="a/b/c")
  inspect(Path::join("/", "a"), content="/a")
  inspect(Path::join("/", "/a"), content="/a")
  inspect(Path::join("//", "a"), content="/a")
  inspect(Path::join("a/b", "../c"), content="a/c")
  inspect(Path::join("/a/b", "../c"), content="/a/c")
  inspect(Path::join("a", ".hidden"), content="a/.hidden")
}

///|
test "normalize node fixtures" {
  inspect(Path::normalize(""), content=".")
  inspect(Path::normalize("."), content=".")
  inspect(Path::normalize("./"), content="./")
  inspect(Path::normalize("a/."), content="a")
  inspect(Path::normalize("a/./"), content="a/")
  inspect(Path::normalize("./a"), content="a")
  inspect(Path::normalize("./a/"), content="a/")
  inspect(Path::normalize("a/./b"), content="a/b")
  inspect(Path::normalize(".."), content="..")
  inspect(Path::normalize("../"), content="../")
  inspect(Path::normalize("a/.."), content=".")
  inspect(Path::normalize("a/../"), content="./")
  inspect(Path::normalize("../a"), content="../a")
  inspect(Path::normalize("a/../b"), content="b")
  inspect(Path::normalize("a/b/.."), content="a")
  inspect(Path::normalize("a/b/../"), content="a/")
  inspect(Path::normalize("a/b/../c"), content="a/c")
  inspect(Path::normalize("a//b"), content="a/b")
  inspect(Path::normalize("a///b"), content="a/b")
  inspect(Path::normalize("//a//b"), content="/a/b")
  inspect(Path::normalize("///a///b"), content="/a/b")
  inspect(Path::normalize("//"), content="/")
  inspect(Path::normalize("///"), content="/")
  inspect(Path::normalize("/."), content="/")
  inspect(Path::normalize("/./"), content="/")
  inspect(Path::normalize("/.."), content="/")
  inspect(Path::normalize("/../"), content="/")
  inspect(Path::normalize("/a/.."), content="/")
  inspect(Path::normalize("/a/../"), content="/")
  inspect(Path::normalize("/a/../b"), content="/b")
  inspect(Path::normalize("a/b/c/"), content="a/b/c/")
  inspect(Path::normalize("a/./b/../c/"), content="a/c/")
  inspect(Path::normalize("a/b/../../../c"), content="../c")
  inspect(Path::normalize("./.hidden"), content=".hidden")
  inspect(Path::normalize("a/./.hidden"), content="a/.hidden")
  inspect(Path::normalize("a/../.hidden"), content=".hidden")
}

///|
test "relative node fixtures" {
  inspect(Path::relative(base="/home/user", "/home/user/proj"), content="proj")
  inspect(Path::relative(base="/home/user/proj", "/home/user"), content="..")
  inspect(Path::relative(base="/home/user", "/home/user"), content="")
  inspect(Path::relative(base="/a/b", "/a/./b"), content="")
  inspect(Path::relative(base="/a/b", "/a/c/../b"), content="")
  inspect(Path::relative(base="/", "/home"), content="home")
  inspect(Path::relative(base="/home", "/"), content="..")
  inspect(Path::relative(base="/a/b/c/d", "/a/b/e/f"), content="../../e/f")
  inspect(Path::relative(base="/a/b/c/d/e", "/a/f"), content="../../../../f")
  inspect(
    Path::relative(base="/home/.config", "/home/.local"),
    content="../.local",
  )
  inspect(Path::relative(base="/home", "/home/.hidden"), content=".hidden")
  inspect(Path::relative(base="/home/user", "/home/user/."), content="")
  inspect(Path::relative(base="/home/user/.", "/home/user"), content="")
  inspect(Path::relative(base="/home/user", "/home/user/.."), content="..")
  inspect(Path::relative(base="/a/b/c", "/a/b/c/../d"), content="../d")
  inspect(Path::relative(base="/a/b/c/../d", "/a/b/c"), content="../c")
}

///|
test "resolve absolute fixtures" {
  inspect(Path::resolve("/a/../b/c"), content="/b/c")
  inspect(Path::resolve("/a/b/c/../../.."), content="/")
  inspect(Path::resolve("/a/./b/c"), content="/a/b/c")
  inspect(Path::resolve("/a/b/../../c"), content="/c")
}

///|
test "resolve drops trailing separators except root" {
  inspect(Path::resolve("/foo/"), content="/foo")
  inspect(Path::resolve("/foo/bar/"), content="/foo/bar")
  inspect(Path::resolve("/foo//bar//"), content="/foo/bar")
  inspect(Path::resolve("/"), content="/")
  inspect(Path::resolve("//"), content="/")
  inspect(Path::resolve("///"), content="/")
}

///|
test "constants and separators" {
  inspect(delimiter, content=":")
  inspect(sep, content="/")
}

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
  inspect(join("", ""))
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
  inspect(normalize(""))
}

///|
test "resolve" {
  inspect(resolve("/a/../b/c"), content="/b/c")
  inspect(resolve("/a/b/c/../../.."), content="/")
}

///|
test "basename edge cases" {
  // Empty path
  inspect(basename(""), content="")

  // Root paths
  inspect(basename("/"), content="")
  inspect(basename("//"), content="")
  inspect(basename("///"), content="")

  // Single character paths
  inspect(basename("a"), content="a")
  inspect(basename("/a"), content="a")

  // Paths with trailing slashes
  inspect(basename("a/"), content="")
  inspect(basename("a/b/"), content="")
  inspect(basename("/a/b/"), content="")
  inspect(basename("a/b//"), content="")

  // Hidden files
  inspect(basename("/a/.hidden"), content=".hidden")
  inspect(basename("/.hidden"), content=".hidden")
  inspect(basename(".hidden"), content=".hidden")
  inspect(basename("/a/."), content=".")
  inspect(basename("/a/.."), content="..")

  // Complex paths
  inspect(basename("./a/b"), content="b")
  inspect(basename("../a/b"), content="b")
  inspect(basename("a/../b"), content="b")
  inspect(basename("/a/../b"), content="b")

  // Paths with special characters
  inspect(basename("/a/b c"), content="b c")
  inspect(basename("/a/b-c"), content="b-c")
  inspect(basename("/a/b_c"), content="b_c")
  inspect(basename("/a/b.c.d"), content="b.c.d")

  // Long paths
  inspect(
    basename("/very/long/path/with/many/components/final"),
    content="final",
  )

  // Paths with multiple consecutive slashes
  inspect(basename("a//b"), content="b")
  inspect(basename("a///b"), content="b")
  inspect(basename("/a//b//c"), content="c")
}

///|
test "dirname edge cases" {
  // Empty path
  inspect(dirname(""), content="")

  // Root paths
  inspect(dirname("/"), content="")
  inspect(dirname("//"), content="/")
  inspect(dirname("///"), content="//")
  inspect(dirname("////"), content="///")

  // Single character paths
  inspect(dirname("a"), content="")
  inspect(dirname("/a"), content="")

  // Paths with trailing slashes
  inspect(dirname("a/"), content="a")
  inspect(dirname("/a/"), content="/a")
  inspect(dirname("a/b/"), content="a/b")

  // Hidden files
  inspect(dirname("/.hidden"), content="")
  inspect(dirname("/a/.hidden"), content="/a")
  inspect(dirname(".hidden"), content="")
  inspect(dirname("/a/."), content="/a")
  inspect(dirname("/a/.."), content="/a")

  // Complex paths
  inspect(dirname("./a"), content=".")
  inspect(dirname("../a"), content="..")
  inspect(dirname("a/../b"), content="a/..")
  inspect(dirname("/a/../b"), content="/a/..")

  // Paths with multiple consecutive slashes
  inspect(dirname("a//b"), content="a")
  inspect(dirname("a///b"), content="a")
  inspect(dirname("/a//b//c"), content="/a//b")

  // Long paths
  inspect(
    dirname("/very/long/path/with/many/components"),
    content="/very/long/path/with/many",
  )
}

///|
test "extname edge cases" {
  // Empty path and no extension
  inspect(extname(""), content="")
  inspect(extname("file"), content="")
  inspect(extname("/path/file"), content="")

  // Hidden files
  inspect(extname(".hidden"), content=".hidden")
  inspect(extname(".hidden.txt"), content=".txt")
  inspect(extname("/path/.hidden"), content=".hidden")
  inspect(extname("/path/.hidden.txt"), content=".txt")

  // Dot files and directories
  inspect(extname("."), content=".")
  inspect(extname(".."), content=".")
  inspect(extname("./file"), content="")
  inspect(extname("../file"), content="")
  inspect(extname("/a/."), content=".")
  inspect(extname("/a/.."), content=".")

  // Multiple extensions
  inspect(extname("file.tar.gz"), content=".gz")
  inspect(extname("archive.tar.bz2"), content=".bz2")
  inspect(extname("config.json.bak"), content=".bak")

  // Extensions with special characters
  inspect(extname("file.c++"), content=".c++")
  inspect(extname("file.123"), content=".123")
  inspect(extname("file.-"), content=".-")

  // Paths with trailing slashes
  inspect(extname("file.txt/"), content="")
  inspect(extname("/path/file.txt/"), content="")

  // Extensions at different positions
  inspect(extname(".txt"), content=".txt")
  inspect(extname("a.b.c"), content=".c")
  inspect(extname("a."), content=".")
  inspect(extname("/path/a."), content=".")

  // Very long extensions
  inspect(extname("file.verylongextension"), content=".verylongextension")
}

///|
test "is_absolute edge cases" {
  // Empty and whitespace
  @json.inspect(is_absolute(""), content=false)
  @json.inspect(is_absolute(" "), content=false)
  @json.inspect(is_absolute("  /"), content=false)

  // Various absolute path formats
  @json.inspect(is_absolute("/"), content=true)
  @json.inspect(is_absolute("//"), content=true)
  @json.inspect(is_absolute("///"), content=true)
  @json.inspect(is_absolute("/a"), content=true)
  @json.inspect(is_absolute("/a/b"), content=true)

  // Relative paths
  @json.inspect(is_absolute("a"), content=false)
  @json.inspect(is_absolute("./a"), content=false)
  @json.inspect(is_absolute("../a"), content=false)
  @json.inspect(is_absolute("a/b"), content=false)
  @json.inspect(is_absolute("a/../b"), content=false)

  // Edge cases with dots
  @json.inspect(is_absolute("."), content=false)
  @json.inspect(is_absolute(".."), content=false)
  @json.inspect(is_absolute("./"), content=false)
  @json.inspect(is_absolute("../"), content=false)
  @json.inspect(is_absolute("/."), content=true)
  @json.inspect(is_absolute("/.."), content=true)
}

///|
test "join edge cases" {
  // Empty strings
  inspect(join("", ""), content="")
  inspect(join("a", ""), content="a/")
  inspect(join("", "b"), content="b")

  // Both paths are absolute
  inspect(join("/a", "/b"), content="/b")
  inspect(join("/a/c", "/b"), content="/b")

  // Various separator combinations
  inspect(join("a", "b/c"), content="a/b/c")
  inspect(join("a/", "b/c"), content="a/b/c")
  inspect(join("a//", "b"), content="a//b")
  inspect(join("a///", "b"), content="a///b")

  // Relative path components
  inspect(join("a", "./b"), content="a/./b")
  inspect(join("a", "../b"), content="a/../b")
  inspect(join("./a", "b"), content="./a/b")
  inspect(join("../a", "b"), content="../a/b")

  // Root paths
  inspect(join("/", "a"), content="/a")
  inspect(join("/", "/a"), content="/a")
  inspect(join("//", "a"), content="//a")

  // Hidden files
  inspect(join("a", ".hidden"), content="a/.hidden")
  inspect(join("/a", ".hidden"), content="/a/.hidden")

  // Complex combinations
  inspect(join("a/b", "../c"), content="a/b/../c")
  inspect(join("/a/b", "../c"), content="/a/b/../c")
  inspect(join("", "/abs"), content="/abs")

  // Multiple consecutive separators
  inspect(join("a//b", "c"), content="a//b/c")
  inspect(join("a", "b//c"), content="a/b//c")
}

///|
test "normalize edge cases" {
  // Empty path
  inspect(normalize(""), content="")

  // Simple dot resolution
  inspect(normalize("."), content="")
  inspect(normalize("./"), content="")
  inspect(normalize("a/."), content="a")
  inspect(normalize("a/./"), content="a")
  inspect(normalize("./a"), content="a")
  inspect(normalize("./a/"), content="a")
  inspect(normalize("a/./b"), content="a/b")

  // Double dot resolution
  inspect(normalize(".."), content="..")
  inspect(normalize("../"), content="..")
  inspect(normalize("a/.."), content="")
  inspect(normalize("a/../"), content="")
  inspect(normalize("../a"), content="../a")
  inspect(normalize("a/../b"), content="b")
  inspect(normalize("a/b/.."), content="a")
  inspect(normalize("a/b/../"), content="a")
  inspect(normalize("a/b/../c"), content="a/c")

  // Multiple consecutive separators
  inspect(normalize("a//b"), content="a/b")
  inspect(normalize("a///b"), content="a/b")
  inspect(normalize("//a//b"), content="//a/b")
  inspect(normalize("///a///b"), content="/a/b")

  // Complex combinations
  inspect(normalize("a/./b/../c"), content="a/c")
  inspect(normalize("./a/../b/./c"), content="b/c")
  inspect(normalize("a/b/../../c"), content="c")
  inspect(normalize("a/b/../../../c"), content="../c")

  // Root paths with dots
  inspect(normalize("/."), content="/")
  inspect(normalize("/./"), content="/")
  inspect(normalize("/.."), content="/")
  inspect(normalize("/../"), content="/")
  inspect(normalize("/a/.."), content="/")
  inspect(normalize("/a/../"), content="/")
  inspect(normalize("/a/../b"), content="/b")

  // Preserve trailing slashes where appropriate
  inspect(normalize("a/b/c/"), content="a/b/c")
  inspect(normalize("a/./b/../c/"), content="a/c")

  // Hidden files
  inspect(normalize("./.hidden"), content=".hidden")
  inspect(normalize("a/./.hidden"), content="a/.hidden")
  inspect(normalize("a/../.hidden"), content=".hidden")
}

///|
test "relative edge cases" {
  // Same paths
  let same1 = "/home/user"
  let same2 = "/home/user"
  inspect(relative(same1, same2), content="")

  // Same paths with different normalization
  inspect(relative("/a/b", "/a/./b"), content="")
  inspect(relative("/a/b", "/a/c/../b"), content="")

  // Root to various paths
  inspect(relative("/", "/home"), content="home")
  inspect(relative("/home", "/"), content="..")

  // Deep nesting
  inspect(relative("/a/b/c/d", "/a/b/e/f"), content="../../e/f")
  inspect(relative("/a/b/c/d/e", "/a/f"), content="../../../../f")

  // Hidden files and directories
  inspect(relative("/home/.config", "/home/.local"), content="../.local")
  inspect(relative("/home", "/home/.hidden"), content=".hidden")

  // Paths with dots
  inspect(relative("/home/user", "/home/user/."), content="")
  inspect(relative("/home/user/.", "/home/user"), content="")
  inspect(relative("/home/user", "/home/user/.."), content="..")

  // Complex relative navigation
  inspect(relative("/a/b/c", "/a/b/c/../d"), content="../d")
  inspect(relative("/a/b/c/../d", "/a/b/c"), content="../c")
}

///|
test "resolve edge cases" {
  // Already absolute paths should be normalized
  inspect(resolve("/a/./b"), content="/a/b")
  inspect(resolve("/a/../b"), content="/b")
  inspect(resolve("/a/b/../../c"), content="/c")
}

///|
test "constants and separators" {
  // Test delimiter constant
  inspect(delimiter, content=":")

  // Test separator constant
  inspect(sep, content="/")
}

///|
test "error boundary conditions" {
  // Test with very long paths
  let long_component = "very_long_directory_name_that_exceeds_normal_length_expectations_and_keeps_going"
  let long_path = "/" +
    long_component +
    "/" +
    long_component +
    "/" +
    long_component

  // These should not crash and should handle gracefully
  ignore(basename(long_path))
  ignore(dirname(long_path))
  ignore(extname(long_path))
  ignore(is_absolute(long_path))
  ignore(normalize(long_path))

  // Test with unusual but valid characters
  let special_chars = "/path/with-special_chars.123/file@name#test"
  ignore(basename(special_chars))
  ignore(dirname(special_chars))
  ignore(extname(special_chars))
  ignore(normalize(special_chars))

  // Test repeated operations
  let path = "/a/b/c"
  let norm1 = normalize(path)
  let norm2 = normalize(norm1)
  inspect(norm1 == norm2, content="true")
}

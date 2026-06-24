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
  debug_inspect(Path::join("a", "b"), content="Path(\"a\\\\b\")")
}

///|
test "basename node fixtures" {
  inspect(Path::basename(""), content="")
  inspect(Path::basename("\\"), content="")
  inspect(Path::basename("\\\\"), content="")
  inspect(Path::basename("a"), content="a")
  inspect(Path::basename("\\a"), content="a")
  inspect(Path::basename("a\\"), content="a")
  inspect(Path::basename("a\\\\"), content="a")
  inspect(Path::basename("a\\b\\"), content="b")
  inspect(Path::basename("C:a"), content="a")
  inspect(Path::basename("C:\\"), content="")
  inspect(Path::basename("C:\\a"), content="a")
  inspect(Path::basename("C:\\a\\b\\"), content="b")
  inspect(Path::basename("file.txt\\"), content="file.txt")
  inspect(Path::basename("a/b"), content="b")
  inspect(Path::basename("//server/share"), content="share")
  inspect(Path::basename("//server/share/"), content="share")
  inspect(Path::basename("//server/share/file"), content="file")
  inspect(Path::basename("\\\\server\\share"), content="share")
  inspect(Path::basename("\\\\server\\share\\"), content="share")
  inspect(Path::basename("\\\\server\\share\\file"), content="file")
  inspect(Path::basename("\\\\server\\share\\folder\\file"), content="file")
  inspect(Path::basename("\\\\?\\C:\\temp\\file"), content="file")
  inspect(Path::basename("\\\\?\\UNC\\server\\share\\file"), content="file")
  inspect(Path::basename("C:\\Program Files\\app"), content="app")
  inspect(Path::basename("C:\\a\\."), content=".")
  inspect(Path::basename("C:\\a\\.."), content="..")
}

///|
test "basename: mixed separator" {
  inspect(Path::basename("a/b\\c"), content="c")
  inspect(Path::basename("a\\b/c"), content="c")
  inspect(Path::basename("C:a/b\\c"), content="c")
  inspect(Path::basename("C:\\a/b\\c"), content="c")
  inspect(Path::basename("//server/share\\file"), content="file")
  inspect(Path::basename("\\\\server/share\\folder/file"), content="file")
  inspect(Path::basename("a/b\\c\\"), content="c")
  inspect(Path::basename("a\\b/c/"), content="c")
}

///|
test "dirname node fixtures" {
  inspect(Path::dirname(""), content=".")
  inspect(Path::dirname("a"), content=".")
  inspect(Path::dirname("a\\"), content=".")
  inspect(Path::dirname("a\\\\"), content=".")
  inspect(Path::dirname("a\\b\\"), content="a")
  inspect(Path::dirname("\\"), content="\\")
  inspect(Path::dirname("\\\\"), content="\\")
  inspect(Path::dirname("\\a"), content="\\")
  inspect(Path::dirname("\\\\a"), content="\\")
  inspect(Path::dirname("C:"), content="C:")
  inspect(Path::dirname("C:a"), content="C:")
  inspect(Path::dirname("C:\\"), content="C:\\")
  inspect(Path::dirname("C:\\a"), content="C:\\")
  inspect(Path::dirname("C:\\a\\"), content="C:\\")
  inspect(Path::dirname("C:/a/b"), content="C:/a")
  inspect(Path::dirname("a/b"), content="a")
  inspect(Path::dirname("///C:/foo"), content="///C:")
  inspect(Path::dirname("//server/share"), content="//server/share")
  inspect(Path::dirname("//server/share/"), content="//server/share/")
  inspect(Path::dirname("//server/share/file"), content="//server/share/")
  inspect(
    Path::dirname("\\\\server\\share\\file"),
    content="\\\\server\\share\\",
  )
  inspect(Path::dirname("\\\\server\\share"), content="\\\\server\\share")
  inspect(Path::dirname("\\\\server\\share\\"), content="\\\\server\\share\\")
  inspect(
    Path::dirname("\\\\server\\share\\folder\\file"),
    content="\\\\server\\share\\folder",
  )
  inspect(Path::dirname("\\\\?\\C:\\temp\\file"), content="\\\\?\\C:\\temp")
  inspect(
    Path::dirname("\\\\?\\UNC\\server\\share\\file"),
    content="\\\\?\\UNC\\server\\share",
  )
  inspect(Path::dirname(".\\a"), content=".")
  inspect(Path::dirname("..\\a"), content="..")
  inspect(Path::dirname("a\\..\\b"), content="a\\..")
  inspect(Path::dirname("C:\\a\\..\\b"), content="C:\\a\\..")
}

///|
test "extname node dotfile fixtures" {
  inspect(Path::extname(""), content="")
  inspect(Path::extname("file"), content="")
  inspect(Path::extname("C:\\path\\file"), content="")
  inspect(Path::extname("project\\main.mbt.md"), content=".md")
  inspect(Path::extname("file.tar.gz"), content=".gz")
  inspect(Path::extname("program.exe"), content=".exe")
  inspect(Path::extname("file.c++"), content=".c++")
  inspect(Path::extname("file.123"), content=".123")
  inspect(Path::extname("file.-"), content=".-")
  inspect(Path::extname(".hidden"), content="")
  inspect(Path::extname("C:\\path\\.hidden"), content="")
  inspect(Path::extname(".hidden.txt"), content=".txt")
  inspect(Path::extname("C:\\path\\.hidden.txt"), content=".txt")
  inspect(Path::extname("."), content="")
  inspect(Path::extname(".."), content="")
  inspect(Path::extname(".\\file"), content="")
  inspect(Path::extname("..\\file"), content="")
  inspect(Path::extname("C:\\a\\."), content="")
  inspect(Path::extname("C:\\a\\.."), content="")
  inspect(Path::extname(".txt"), content="")
  inspect(Path::extname("a.b.c"), content=".c")
  inspect(Path::extname("a."), content=".")
  inspect(Path::extname("C:\\path\\a."), content=".")
  inspect(Path::extname("file.txt\\"), content=".txt")
  inspect(Path::extname("C:\\path\\file.txt\\"), content=".txt")
  inspect(Path::extname("a/b.txt"), content=".txt")
  inspect(Path::extname("\\\\server\\share\\file.txt"), content=".txt")
  inspect(Path::extname("\\\\?\\C:\\temp\\file.log"), content=".log")
}

///|
test "is_absolute node fixtures" {
  json_inspect(Path::is_absolute(""), content=false)
  json_inspect(Path::is_absolute(" "), content=false)
  json_inspect(Path::is_absolute("  \\"), content=false)
  json_inspect(Path::is_absolute("\\"), content=true)
  json_inspect(Path::is_absolute("\\\\"), content=true)
  json_inspect(Path::is_absolute("/foo"), content=true)
  json_inspect(Path::is_absolute("foo/bar"), content=false)
  json_inspect(Path::is_absolute("C:"), content=false)
  json_inspect(Path::is_absolute("C:temp"), content=false)
  json_inspect(Path::is_absolute("C:temp\\file"), content=false)
  json_inspect(Path::is_absolute("C:\\"), content=true)
  json_inspect(Path::is_absolute("C:\\temp"), content=true)
  json_inspect(Path::is_absolute("C:/temp"), content=true)
  json_inspect(Path::is_absolute("c:/temp"), content=true)
  json_inspect(Path::is_absolute("\\\\server\\share"), content=true)
  json_inspect(Path::is_absolute("//server/share"), content=true)
  json_inspect(Path::is_absolute("\\\\?\\C:\\"), content=true)
  json_inspect(Path::is_absolute("\\\\?\\C:\\temp"), content=true)
  json_inspect(Path::is_absolute("\\\\?\\UNC\\server\\share"), content=true)
  json_inspect(
    Path::is_absolute("\\\\?\\UNC\\server\\share\\file"),
    content=true,
  )
  json_inspect(Path::is_absolute("\\\\.\\COM1"), content=true)
  json_inspect(Path::is_absolute("\\\\.\\PhysicalDrive0"), content=true)
  json_inspect(
    Path::is_absolute("\\\\?\\Volume{12345678-1234-1234-1234-1234567890ab}\\"),
    content=true,
  )
  json_inspect(Path::is_absolute("."), content=false)
  json_inspect(Path::is_absolute(".."), content=false)
  json_inspect(Path::is_absolute(".\\"), content=false)
  json_inspect(Path::is_absolute("..\\"), content=false)
  json_inspect(Path::is_absolute("\\."), content=true)
  json_inspect(Path::is_absolute("\\.."), content=true)
}

///|
test "join node fixtures" {
  inspect(Path::join("a", "b"), content="a\\b")
  inspect(Path::join("a", "\\b"), content="a\\b")
  inspect(Path::join("C:\\a", "D:\\b"), content="C:\\a\\D:\\b")
  inspect(Path::join("lhs", "C:rhs"), content="lhs\\C:rhs")
  inspect(Path::join("C:lhs", "C:rhs"), content="C:lhs\\C:rhs")
  inspect(Path::join("C:lhs", "D:rhs"), content="C:lhs\\D:rhs")
  inspect(Path::join("", ""), content=".")
  inspect(Path::join("a", ""), content="a")
  inspect(Path::join("", "b"), content="b")
  inspect(Path::join("", "C:\\abs"), content="C:\\abs")
  inspect(Path::join("a", "b/c"), content="a\\b\\c")
  inspect(Path::join("a\\", "b\\c"), content="a\\b\\c")
  inspect(Path::join("a\\\\", "b"), content="a\\b")
  inspect(Path::join("a", ".\\b"), content="a\\b")
  inspect(Path::join("a", "..\\b"), content="b")
  inspect(Path::join(".\\a", "b"), content="a\\b")
  inspect(Path::join("..\\a", "b"), content="..\\a\\b")
  inspect(Path::join("C:", "temp"), content="C:\\temp")
  inspect(Path::join("C:\\", "temp"), content="C:\\temp")
  inspect(Path::join("C:\\folder", "temp"), content="C:\\folder\\temp")
  inspect(Path::join("C:folder", "temp"), content="C:folder\\temp")
  inspect(
    Path::join("\\\\server1\\share1", "\\\\server2\\share2"),
    content="\\\\server1\\share1\\server2\\share2",
  )
  inspect(
    Path::join("//server/share", "folder"),
    content="\\\\server\\share\\folder",
  )
  inspect(Path::join("\\", "a"), content="\\a")
  inspect(Path::join("\\", "\\a"), content="\\a")
  inspect(Path::join("\\\\", "a"), content="\\a")
  inspect(Path::join("a\\b", "..\\c"), content="a\\c")
  inspect(Path::join("C:\\a\\b", "..\\c"), content="C:\\a\\c")
  inspect(Path::join("C:\\temp", "CON"), content="C:\\temp\\CON")
  inspect(Path::join("C:\\temp", "PRN.txt"), content="C:\\temp\\PRN.txt")
  inspect(Path::join("a", "C:"), content=".\\a\\C:")
  inspect(Path::join("a", "C:\\b"), content=".\\a\\C:\\b")
}

///|
test "normalize node fixtures" {
  inspect(Path::normalize(""), content=".")
  inspect(Path::normalize("."), content=".")
  inspect(Path::normalize(".\\"), content=".\\")
  inspect(Path::normalize("a\\."), content="a")
  inspect(Path::normalize("a\\.\\b"), content="a\\b")
  inspect(Path::normalize(".\\a"), content="a")
  inspect(Path::normalize(".\\a\\"), content="a\\")
  inspect(Path::normalize(".."), content="..")
  inspect(Path::normalize("..\\"), content="..\\")
  inspect(Path::normalize("a\\.."), content=".")
  inspect(Path::normalize("a\\..\\"), content=".\\")
  inspect(Path::normalize("..\\a"), content="..\\a")
  inspect(Path::normalize("a\\..\\b"), content="b")
  inspect(Path::normalize("a\\b\\.."), content="a")
  inspect(Path::normalize("a\\b\\..\\"), content="a\\")
  inspect(Path::normalize("a\\b\\..\\c"), content="a\\c")
  inspect(Path::normalize("a\\\\b"), content="a\\b")
  inspect(Path::normalize("a\\\\\\b"), content="a\\b")
  inspect(Path::normalize("a/b//c"), content="a\\b\\c")
  inspect(Path::normalize("a\\b\\c\\"), content="a\\b\\c\\")
  inspect(Path::normalize("a\\.\\b\\..\\c\\"), content="a\\c\\")
  inspect(Path::normalize("C:\\.\\temp"), content="C:\\temp")
  inspect(Path::normalize("C:\\..\\temp"), content="C:\\temp")
  inspect(Path::normalize("C:\\folder\\..\\temp"), content="C:\\temp")
  inspect(Path::normalize("C:temp\\.\\file"), content="C:temp\\file")
  inspect(Path::normalize("\\."), content="\\")
  inspect(Path::normalize("\\./"), content="\\")
  inspect(Path::normalize("\\.."), content="\\")
  inspect(Path::normalize("\\..\\"), content="\\")
  inspect(Path::normalize("\\a\\.."), content="\\")
  inspect(Path::normalize("\\a\\..\\"), content="\\")
  inspect(Path::normalize("\\a\\..\\b"), content="\\b")
  inspect(Path::normalize("///server/share"), content="\\server\\share")
  inspect(
    Path::normalize("\\\\server\\share\\.\\folder"),
    content="\\\\server\\share\\folder",
  )
  inspect(
    Path::normalize("\\\\server\\share\\folder\\..\\file"),
    content="\\\\server\\share\\file",
  )
  inspect(
    Path::normalize("//server/share//folder"),
    content="\\\\server\\share\\folder",
  )
  inspect(Path::normalize(".\\.hidden"), content=".hidden")
  inspect(Path::normalize("a\\.\\.hidden"), content="a\\.hidden")
  inspect(Path::normalize("a\\..\\..hidden"), content="..hidden")
  inspect(
    Path::normalize("\\\\?\\C:\\temp\\.\\file"),
    content="\\\\?\\C:\\temp\\file",
  )
  inspect(
    Path::normalize("\\\\?\\UNC\\server\\share\\folder\\..\\file"),
    content="\\\\?\\UNC\\server\\share\\file",
  )
  inspect(
    Path::normalize("\\\\?\\UNC\\server\\share\\.."),
    content="\\\\?\\UNC\\server",
  )
  inspect(
    Path::normalize("\\\\?\\UNC\\server\\share\\folder\\.."),
    content="\\\\?\\UNC\\server\\share",
  )
  inspect(Path::normalize("\\\\?\\foo\\.."), content="\\\\?\\")
  inspect(Path::normalize("\\\\?\\foo\\bar\\.."), content="\\\\?\\foo")
  inspect(Path::normalize("\\\\.\\COM1\\.."), content="\\\\.\\")
  inspect(Path::normalize("\\\\.\\COM1\\bar\\.."), content="\\\\.\\COM1")
  inspect(Path::normalize("\\\\?\\Volume{abc}\\.."), content="\\\\?\\")
  inspect(
    Path::normalize("\\\\?\\Volume{abc}\\bar\\.."),
    content="\\\\?\\Volume{abc}",
  )
  inspect(Path::normalize("\\\\?\\C:\\foo\\.."), content="\\\\?\\C:")
  inspect(Path::normalize("\\\\?\\C:\\.."), content="\\\\?\\")
  inspect(
    Path::normalize("\\\\?\\UNC\\server\\"),
    content="\\\\?\\UNC\\server\\",
  )
  inspect(Path::normalize("C:\\temp\\CON"), content="C:\\temp\\CON")
  inspect(Path::normalize("C:\\temp\\PRN.txt"), content="C:\\temp\\PRN.txt")
  inspect(Path::normalize("a\\C:"), content=".\\a\\C:")
  inspect(Path::normalize("a\\C:\\b"), content=".\\a\\C:\\b")
  inspect(Path::normalize("foo\\bar\\D:\\baz"), content=".\\foo\\bar\\D:\\baz")
}

///|
test "relative node fixtures" {
  inspect(
    Path::relative(base="C:\\Users\\user", "C:\\Users\\user\\proj"),
    content="proj",
  )
  inspect(
    Path::relative(base="C:\\Users\\user\\proj", "C:\\Users\\user"),
    content="..",
  )
  inspect(Path::relative(base="C:\\Users\\user", "C:\\Users\\user"), content="")
  inspect(Path::relative(base="C:\\a\\b", "C:\\a\\.\\b"), content="")
  inspect(Path::relative(base="C:\\a\\b", "C:\\a\\c\\..\\b"), content="")
  inspect(Path::relative(base="C:\\temp", "D:\\temp"), content="D:\\temp")
  inspect(Path::relative(base="C:\\Users", "D:\\Files"), content="D:\\Files")
  inspect(Path::relative(base="C:\\", "C:\\Users"), content="Users")
  inspect(Path::relative(base="C:\\Users", "C:\\"), content="..")
  inspect(
    Path::relative(base="C:\\a\\b\\c\\d", "C:\\a\\b\\e\\f"),
    content="..\\..\\e\\f",
  )
  inspect(
    Path::relative(base="C:\\a\\b\\c\\d\\e", "C:\\a\\f"),
    content="..\\..\\..\\..\\f",
  )
  inspect(
    Path::relative(base="C:\\Users\\.config", "C:\\Users\\.local"),
    content="..\\.local",
  )
  inspect(
    Path::relative(base="C:\\Users", "C:\\Users\\.hidden"),
    content=".hidden",
  )
  inspect(
    Path::relative(base="C:\\Users\\user", "C:\\Users\\user\\."),
    content="",
  )
  inspect(
    Path::relative(base="C:\\Users\\user\\.", "C:\\Users\\user"),
    content="",
  )
  inspect(
    Path::relative(base="C:\\Users\\user", "C:\\Users\\user\\.."),
    content="..",
  )
  inspect(
    Path::relative(
      base="\\\\server\\share\\folder1",
      "\\\\server\\share\\folder2",
    ),
    content="..\\folder2",
  )
  inspect(Path::relative(base="c:\\temp", "C:\\temp\\file"), content="file")
  inspect(Path::relative(base="C:\\Ä", "C:\\ä"), content="")
  inspect(
    Path::relative(base="\\\\server\\share", "\\\\server\\other\\file"),
    content="..\\other\\file",
  )
  inspect(
    Path::relative(base="\\\\server\\share\\folder", "\\\\server\\other\\file"),
    content="..\\..\\other\\file",
  )
  inspect(
    Path::relative(base="\\\\server1\\share", "\\\\server2\\share\\file"),
    content="\\\\server2\\share\\file",
  )
  inspect(
    Path::relative(
      base="\\\\?\\UNC\\server\\share",
      "\\\\?\\UNC\\server\\other\\file",
    ),
    content="..\\other\\file",
  )
  inspect(Path::relative(base="\\a", "\\b"), content="\\b")
  inspect(Path::relative(base="/a/b", "/c/d"), content="\\c\\d")
  inspect(Path::relative(base="/a/b", "/a/c"), content="..\\c")
}

///|
test "resolve absolute fixtures" {
  inspect(Path::resolve("C:\\a\\.\\b"), content="C:\\a\\b")
  inspect(Path::resolve("C:\\a\\..\\b"), content="C:\\b")
  inspect(Path::resolve("C:\\a\\b\\..\\..\\c"), content="C:\\c")
  inspect(Path::resolve("\\a\\..\\b\\c"), content="\\b\\c")
  inspect(
    Path::resolve("\\\\server\\share\\.\\file"),
    content="\\\\server\\share\\file",
  )
  inspect(
    Path::resolve("\\\\?\\C:\\temp\\.\\file"),
    content="\\\\?\\C:\\temp\\file",
  )
}

///|
test "resolve drops trailing separators except regular roots" {
  inspect(Path::resolve("C:\\a\\"), content="C:\\a")
  inspect(Path::resolve("C:\\a\\b\\"), content="C:\\a\\b")
  inspect(
    Path::resolve("\\\\server\\share\\file\\"),
    content="\\\\server\\share\\file",
  )
  inspect(Path::resolve("\\\\?\\C:\\temp\\"), content="\\\\?\\C:\\temp")
  inspect(
    Path::resolve("\\\\?\\UNC\\server\\share\\file\\"),
    content="\\\\?\\UNC\\server\\share\\file",
  )
  inspect(Path::resolve("\\\\?\\C:\\"), content="\\\\?\\C:")
  inspect(
    Path::resolve("\\\\?\\UNC\\server\\share\\"),
    content="\\\\?\\UNC\\server\\share",
  )
  inspect(Path::resolve("\\\\?\\UNC\\server\\"), content="\\\\?\\UNC\\server")
  inspect(Path::resolve("\\\\.\\COM1\\"), content="\\\\.\\COM1")
  inspect(Path::resolve("\\"), content="\\")
  inspect(Path::resolve("C:\\"), content="C:\\")
  inspect(Path::resolve("\\\\server\\share\\"), content="\\\\server\\share\\")
}

///|
fn test_is_ascii_alpha(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn test_is_win_sep_at(path : String, index : Int) -> Bool {
  match path.get_char(index) {
    Some('\\' | '/') => true
    _ => false
  }
}

///|
fn test_has_win_drive(path : String) -> Bool {
  if path.length() < 2 || path.get_char(1) != Some(':') {
    false
  } else {
    match path.get_char(0) {
      Some(ch) => test_is_ascii_alpha(ch)
      _ => false
    }
  }
}

///|
fn test_current_dir_for_drive(drive : String) -> Path {
  let cwd = @env.current_dir().unwrap()
  if test_has_win_drive(cwd) &&
    !cwd[0:2].equal_ignore_ascii_case(drive) &&
    cwd.length() > 2 &&
    test_is_win_sep_at(cwd, 2) {
    Path::normalize(drive + "\\")
  } else if !test_has_win_drive(cwd) &&
    cwd.length() > 0 &&
    test_is_win_sep_at(cwd, 0) {
    Path::normalize(drive + cwd)
  } else if !test_has_win_drive(cwd) {
    Path::normalize(drive + "\\" + cwd)
  } else {
    Path::normalize(cwd)
  }
}

///|
test "resolve drive-relative paths from current directory" {
  let c_cwd = test_current_dir_for_drive("C:")
  inspect(Path::resolve("C:"), content=c_cwd.to_string())
  inspect(Path::resolve("C:."), content=c_cwd.to_string())
  inspect(Path::resolve("C:a"), content=c_cwd.join("a").to_string())
  inspect(Path::resolve("C:a\\..\\b"), content=c_cwd.join("b").to_string())
  inspect(
    Path::resolve("D:a"),
    content=test_current_dir_for_drive("D:").join("a").to_string(),
  )
}

///|
test "constants and separators" {
  inspect(delimiter, content=";")
  inspect(sep, content="\\")
}

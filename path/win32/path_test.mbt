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

///|
test "basename edge cases" {
  // Empty path
  inspect(basename(""), content="")

  // Root paths
  inspect(basename("\\"), content="")
  inspect(basename("\\\\"), content="")
  inspect(basename("\\\\\\"), content="")
  inspect(basename("C:\\"), content="")

  // Single character paths
  inspect(basename("a"), content="a")
  inspect(basename("\\a"), content="a")
  inspect(basename("C:a"), content="C:a")
  inspect(basename("C:\\a"), content="a")

  // Paths with trailing backslashes
  inspect(basename("a\\"), content="")
  inspect(basename("a\\b\\"), content="")
  inspect(basename("C:\\a\\b\\"), content="")
  inspect(basename("a\\b\\\\"), content="")

  // Hidden files (starting with dot)
  inspect(basename("C:\\a\\.hidden"), content=".hidden")
  inspect(basename("C:\\.hidden"), content=".hidden")
  inspect(basename(".hidden"), content=".hidden")
  inspect(basename("C:\\a\\."), content=".")
  inspect(basename("C:\\a\\.."), content="..")

  // Complex paths
  inspect(basename(".\\a\\b"), content="b")
  inspect(basename("..\\a\\b"), content="b")
  inspect(basename("a\\..\\b"), content="b")
  inspect(basename("C:\\a\\..\\b"), content="b")

  // Paths with special characters and spaces
  inspect(basename("C:\\a\\b c"), content="b c")
  inspect(basename("C:\\a\\b-c"), content="b-c")
  inspect(basename("C:\\a\\b_c"), content="b_c")
  inspect(basename("C:\\a\\b.c.d"), content="b.c.d")
  inspect(basename("C:\\Program Files\\app"), content="app")

  // UNC paths
  inspect(basename("\\\\server\\share\\file"), content="file")
  inspect(basename("\\\\server\\share\\folder\\file"), content="file")
  inspect(basename("\\\\server\\share\\"), content="")

  // Verbatim paths
  inspect(basename("\\\\?\\C:\\temp\\file"), content="file")
  inspect(basename("\\\\?\\UNC\\server\\share\\file"), content="file")

  // Long paths
  inspect(
    basename("C:\\very\\long\\path\\with\\many\\components\\final"),
    content="final",
  )

  // Paths with multiple consecutive backslashes
  inspect(basename("a\\\\b"), content="b")
  inspect(basename("a\\\\\\b"), content="b")
  inspect(basename("C:\\a\\\\b\\\\c"), content="c")

  // Mixed separators (forward slash in Windows)
  inspect(basename("C:/a/b"), content="C:/a/b") // No backslash found, returns whole string
}

///|
test "dirname edge cases" {
  // Empty path
  inspect(dirname(""), content="")

  // Root paths
  inspect(dirname("\\"), content="")
  inspect(dirname("\\\\"), content="\\")
  inspect(dirname("\\\\\\"), content="\\\\")
  inspect(dirname("C:\\"), content="C:")
  inspect(dirname("C:"), content="")

  // Single character paths
  inspect(dirname("a"), content="")
  inspect(dirname("\\a"), content="")
  inspect(dirname("C:a"), content="")
  inspect(dirname("C:\\a"), content="C:")

  // Paths with trailing backslashes
  inspect(dirname("a\\"), content="a")
  inspect(dirname("C:\\a\\"), content="C:\\a")
  inspect(dirname("a\\b\\"), content="a\\b")

  // Hidden files
  inspect(dirname("C:\\.hidden"), content="C:")
  inspect(dirname("C:\\a\\.hidden"), content="C:\\a")
  inspect(dirname(".hidden"), content="")
  inspect(dirname("C:\\a\\."), content="C:\\a")
  inspect(dirname("C:\\a\\.."), content="C:\\a")

  // Complex paths
  inspect(dirname(".\\a"), content=".")
  inspect(dirname("..\\a"), content="..")
  inspect(dirname("a\\..\\b"), content="a\\..")
  inspect(dirname("C:\\a\\..\\b"), content="C:\\a\\..")

  // UNC paths
  inspect(dirname("\\\\server\\share\\file"), content="\\\\server\\share")
  inspect(
    dirname("\\\\server\\share\\folder\\file"),
    content="\\\\server\\share\\folder",
  )
  inspect(dirname("\\\\server\\share"), content="\\\\server")

  // Verbatim paths
  inspect(dirname("\\\\?\\C:\\temp\\file"), content="\\\\?\\C:\\temp")
  inspect(
    dirname("\\\\?\\UNC\\server\\share\\file"),
    content="\\\\?\\UNC\\server\\share",
  )

  // Paths with multiple consecutive backslashes
  inspect(dirname("a\\\\b"), content="a")
  inspect(dirname("a\\\\\\b"), content="a")
  inspect(dirname("C:\\a\\\\b\\\\c"), content="C:\\a\\\\b")

  // Long paths
  inspect(
    dirname("C:\\very\\long\\path\\with\\many\\components"),
    content="C:\\very\\long\\path\\with\\many",
  )
}

///|
test "extname edge cases" {
  // Empty path and no extension
  inspect(extname(""), content="")
  inspect(extname("file"), content="")
  inspect(extname("C:\\path\\file"), content="")

  // Hidden files
  inspect(extname(".hidden"), content=".hidden")
  inspect(extname(".hidden.txt"), content=".txt")
  inspect(extname("C:\\path\\.hidden"), content=".hidden")
  inspect(extname("C:\\path\\.hidden.txt"), content=".txt")

  // Dot files and directories
  inspect(extname("."), content=".")
  inspect(extname(".."), content=".")
  inspect(extname(".\\file"), content="")
  inspect(extname("..\\file"), content="")
  inspect(extname("C:\\a\\."), content=".")
  inspect(extname("C:\\a\\.."), content=".")

  // Multiple extensions
  inspect(extname("file.tar.gz"), content=".gz")
  inspect(extname("archive.tar.bz2"), content=".bz2")
  inspect(extname("config.json.bak"), content=".bak")

  // Extensions with special characters
  inspect(extname("file.c++"), content=".c++")
  inspect(extname("file.123"), content=".123")
  inspect(extname("file.-"), content=".-")

  // Paths with trailing backslashes
  inspect(extname("file.txt\\"), content="")
  inspect(extname("C:\\path\\file.txt\\"), content="")

  // Extensions at different positions
  inspect(extname(".txt"), content=".txt")
  inspect(extname("a.b.c"), content=".c")
  inspect(extname("a."), content=".")
  inspect(extname("C:\\path\\a."), content=".")

  // Windows specific extensions
  inspect(extname("program.exe"), content=".exe")
  inspect(extname("library.dll"), content=".dll")
  inspect(extname("config.ini"), content=".ini")
  inspect(extname("batch.bat"), content=".bat")
  inspect(extname("command.cmd"), content=".cmd")

  // UNC paths with extensions
  inspect(extname("\\\\server\\share\\file.txt"), content=".txt")
  inspect(extname("\\\\?\\C:\\temp\\file.log"), content=".log")

  // Very long extensions
  inspect(extname("file.verylongextension"), content=".verylongextension")
}

///|
test "is_absolute advanced edge cases" {
  // Empty and whitespace
  @json.inspect(is_absolute(""), content=false)
  @json.inspect(is_absolute(" "), content=false)
  @json.inspect(is_absolute("  \\"), content=false)

  // Basic absolute paths
  @json.inspect(is_absolute("\\"), content=true)
  @json.inspect(is_absolute("\\\\"), content=true) // This might be interpreted as start of UNC
  @json.inspect(is_absolute("\\\\\\"), content=true)
  @json.inspect(is_absolute("C:\\"), content=true)
  @json.inspect(is_absolute("D:\\temp"), content=true)

  // Relative paths with drive letters
  @json.inspect(is_absolute("C:"), content=false)
  @json.inspect(is_absolute("C:temp"), content=false)
  @json.inspect(is_absolute("C:temp\\file"), content=false)
  @json.inspect(is_absolute("Z:relative"), content=false)

  // Various UNC path formats
  @json.inspect(is_absolute("\\\\server\\share"), content=true)
  @json.inspect(is_absolute("\\\\server\\share\\"), content=true)
  @json.inspect(is_absolute("\\\\server\\share\\file"), content=true)
  @json.inspect(is_absolute("\\\\localhost\\c$\\temp"), content=true)
  @json.inspect(is_absolute("\\\\127.0.0.1\\share\\file"), content=true)

  // Verbatim path formats
  @json.inspect(is_absolute("\\\\?\\C:\\"), content=true)
  @json.inspect(is_absolute("\\\\?\\C:\\temp"), content=true)
  @json.inspect(is_absolute("\\\\?\\D:\\very\\long\\path"), content=true)

  // Verbatim UNC paths
  @json.inspect(is_absolute("\\\\?\\UNC\\server\\share"), content=true)
  @json.inspect(is_absolute("\\\\?\\UNC\\server\\share\\file"), content=true)

  // Device namespace paths
  @json.inspect(is_absolute("\\\\.\\COM1"), content=true)
  @json.inspect(is_absolute("\\\\.\\LPT1"), content=true)
  @json.inspect(is_absolute("\\\\.\\PRN"), content=true)
  @json.inspect(is_absolute("\\\\.\\AUX"), content=true)
  @json.inspect(is_absolute("\\\\.\\NUL"), content=true)
  @json.inspect(is_absolute("\\\\.\\CON"), content=true)
  @json.inspect(is_absolute("\\\\.\\PhysicalDrive0"), content=true)

  // Volume GUID paths
  @json.inspect(
    is_absolute("\\\\?\\Volume{12345678-1234-1234-1234-1234567890ab}\\"),
    content=true,
  )
  @json.inspect(
    is_absolute("\\\\?\\Volume{12345678-1234-1234-1234-1234567890ab}\\temp"),
    content=true,
  )

  // Global root paths
  @json.inspect(
    is_absolute("\\\\?\\GLOBALROOT\\Device\\HarddiskVolume1\\"),
    content=true,
  )
  @json.inspect(
    is_absolute("\\\\?\\GLOBALROOT\\Device\\HarddiskVolume1\\temp"),
    content=true,
  )

  // Relative paths
  @json.inspect(is_absolute("temp"), content=false)
  @json.inspect(is_absolute("temp\\file"), content=false)
  @json.inspect(is_absolute(".\\temp"), content=false)
  @json.inspect(is_absolute("..\\temp"), content=false)
  @json.inspect(is_absolute("folder\\subfolder"), content=false)

  // Edge cases with dots
  @json.inspect(is_absolute("."), content=false)
  @json.inspect(is_absolute(".."), content=false)
  @json.inspect(is_absolute(".\\"), content=false)
  @json.inspect(is_absolute("..\\"), content=false)
  @json.inspect(is_absolute("\\."), content=true)
  @json.inspect(is_absolute("\\.."), content=true)

  // Case sensitivity tests (Windows is case-insensitive)
  @json.inspect(is_absolute("c:\\"), content=true)
  @json.inspect(is_absolute("C:\\"), content=true)
  @json.inspect(is_absolute("z:\\temp"), content=true)
  @json.inspect(is_absolute("Z:\\temp"), content=true)
}

///|
test "join edge cases" {
  // Empty strings
  inspect(join("", ""), content="")
  inspect(join("a", ""), content="a\\")
  inspect(join("", "b"), content="b")

  // Both paths are absolute - second wins
  inspect(join("C:\\a", "D:\\b"), content="D:\\b")
  inspect(join("C:\\a\\c", "\\b"), content="\\b")
  inspect(
    join("\\\\server1\\share1", "\\\\server2\\share2"),
    content="\\\\server2\\share2",
  )

  // Drive letter combinations
  inspect(join("C:", "temp"), content="C:\\temp")
  inspect(join("C:\\", "temp"), content="C:\\temp")
  inspect(join("C:\\folder", "temp"), content="C:\\folder\\temp")
  inspect(join("C:folder", "temp"), content="C:folder\\temp")

  // Various separator combinations
  inspect(join("a", "b\\c"), content="a\\b\\c")
  inspect(join("a\\", "b\\c"), content="a\\b\\c")
  inspect(join("a\\\\", "b"), content="a\\\\b")
  inspect(join("a\\\\\\", "b"), content="a\\\\\\b")

  // Relative path components
  inspect(join("a", ".\\b"), content="a\\.\\b")
  inspect(join("a", "..\\b"), content="a\\..\\b")
  inspect(join(".\\a", "b"), content=".\\a\\b")
  inspect(join("..\\a", "b"), content="..\\a\\b")

  // UNC paths
  inspect(
    join("\\\\server\\share", "folder"),
    content="\\\\server\\share\\folder",
  )
  inspect(
    join("\\\\server\\share\\", "folder"),
    content="\\\\server\\share\\folder",
  )

  // Verbatim paths
  inspect(join("\\\\?\\C:\\temp", "file"), content="\\\\?\\C:\\temp\\file")
  inspect(join("\\\\?\\C:\\temp\\", "file"), content="\\\\?\\C:\\temp\\file")

  // Root paths
  inspect(join("\\", "a"), content="\\a")
  inspect(join("\\", "\\a"), content="\\a")
  inspect(join("\\\\", "a"), content="\\\\a")

  // Hidden files
  inspect(join("a", ".hidden"), content="a\\.hidden")
  inspect(join("C:\\a", ".hidden"), content="C:\\a\\.hidden")

  // Complex combinations
  inspect(join("a\\b", "..\\c"), content="a\\b\\..\\c")
  inspect(join("C:\\a\\b", "..\\c"), content="C:\\a\\b\\..\\c")
  inspect(join("", "C:\\abs"), content="C:\\abs")

  // Multiple consecutive separators
  inspect(join("a\\\\b", "c"), content="a\\\\b\\c")
  inspect(join("a", "b\\\\c"), content="a\\b\\\\c")

  // Special Windows device names
  inspect(join("C:\\temp", "CON"), content="C:\\temp\\CON")
  inspect(join("C:\\temp", "PRN.txt"), content="C:\\temp\\PRN.txt")
}

///|
test "normalize edge cases" {
  // Empty path
  inspect(normalize(""), content="")

  // Simple dot resolution
  inspect(normalize("."), content="")
  inspect(normalize(".\\"), content="")
  inspect(normalize("a\\."), content="a")
  inspect(normalize(".\\a"), content="a")
  inspect(normalize(".\\a\\"), content="a")
  inspect(normalize("a\\.\\b"), content="a\\b")

  // Double dot resolution
  inspect(normalize(".."), content="..")
  inspect(normalize("..\\"), content="..")
  inspect(normalize("a\\.."), content="")
  inspect(normalize("a\\..\\"), content="")
  inspect(normalize("..\\a"), content="..\\a")
  inspect(normalize("a\\..\\b"), content="b")
  inspect(normalize("a\\b\\.."), content="a")
  inspect(normalize("a\\b\\..\\"), content="a")
  inspect(normalize("a\\b\\..\\c"), content="a\\c")

  // Multiple consecutive separators
  inspect(normalize("a\\\\b"), content="a\\b")
  inspect(normalize("a\\\\\\b"), content="a\\b")
  inspect(normalize("\\\\a\\\\b"), content="\\\\a\\\\b")
  inspect(normalize("\\\\\\a\\\\\\b"), content="\\\\\\a\\\\\\b")

  // Drive letter paths
  inspect(normalize("C:\\.\\temp"), content="C:\\temp")
  inspect(normalize("C:\\..\\temp"), content="C:\\temp")
  inspect(normalize("C:\\folder\\..\\temp"), content="C:\\temp")
  inspect(normalize("C:temp\\.\\file"), content="C:temp\\file")

  // UNC path normalization
  inspect(
    normalize("\\\\server\\share\\.\\folder"),
    content="\\\\server\\share\\folder",
  )
  inspect(
    normalize("\\\\server\\share\\folder\\..\\file"),
    content="\\\\server\\share\\file",
  )

  // Complex combinations
  inspect(normalize("a\\.\\b\\..\\c"), content="a\\c")
  inspect(normalize(".\\a\\..\\b\\.\\c"), content="b\\c")
  inspect(normalize("a\\b\\..\\..\\c"), content="c")
  inspect(normalize("a\\b\\..\\..\\..\\c"), content="..\\c")

  // Root paths with dots
  inspect(normalize("\\."), content="\\")
  inspect(normalize("\\./"), content="\\./")
  inspect(normalize("\\.."), content="\\")
  inspect(normalize("\\..\\"), content="\\")
  inspect(normalize("\\a\\.."), content="\\")
  inspect(normalize("\\a\\..\\"), content="\\")
  inspect(normalize("\\a\\..\\b"), content="\\b")

  // Preserve trailing backslashes where appropriate
  inspect(normalize("a\\b\\c\\"), content="a\\b\\c")
  inspect(normalize("a\\.\\b\\..\\c\\"), content="a\\c")

  // Hidden files
  inspect(normalize(".\\.hidden"), content=".hidden")
  inspect(normalize("a\\.\\.hidden"), content="a\\.hidden")
  inspect(normalize("a\\..\\..hidden"), content="..hidden")

  // Verbatim paths (should preserve structure)
  inspect(
    normalize("\\\\?\\C:\\temp\\.\\file"),
    content="\\\\?\\C:\\temp\\file",
  )
  inspect(
    normalize("\\\\?\\UNC\\server\\share\\folder\\..\\file"),
    content="\\\\?\\UNC\\server\\share\\file",
  )
}

///|
test "relative edge cases" {
  // Same paths
  let same1 = "C:\\Users\\user"
  let same2 = "C:\\Users\\user"
  inspect(relative(same1, same2), content="")

  // Same paths with different normalization
  inspect(relative("C:\\a\\b", "C:\\a\\.\\b"), content="")
  inspect(relative("C:\\a\\b", "C:\\a\\c\\..\\b"), content="")

  // Different drives should return empty (different prefixes)
  inspect(relative("C:\\temp", "D:\\temp"), content="")
  inspect(relative("C:\\Users", "D:\\Files"), content="")

  // Root to various paths
  inspect(relative("C:\\", "C:\\Users"), content="Users")
  inspect(relative("C:\\Users", "C:\\"), content="..")

  // Deep nesting
  inspect(relative("C:\\a\\b\\c\\d", "C:\\a\\b\\e\\f"), content="..\\..\\e\\f")
  inspect(
    relative("C:\\a\\b\\c\\d\\e", "C:\\a\\f"),
    content="..\\..\\..\\..\\f",
  )

  // Hidden files and directories
  inspect(
    relative("C:\\Users\\.config", "C:\\Users\\.local"),
    content="..\\.local",
  )
  inspect(relative("C:\\Users", "C:\\Users\\.hidden"), content=".hidden")

  // Paths with dots
  inspect(relative("C:\\Users\\user", "C:\\Users\\user\\."), content="")
  inspect(relative("C:\\Users\\user\\.", "C:\\Users\\user"), content="")
  inspect(relative("C:\\Users\\user", "C:\\Users\\user\\.."), content="..")

  // UNC paths
  inspect(
    relative("\\\\server\\share\\folder1", "\\\\server\\share\\folder2"),
    content="..\\folder2",
  )
  inspect(relative("\\\\server1\\share", "\\\\server2\\share"), content="") // Different prefixes

  // Complex relative navigation
  inspect(relative("C:\\a\\b\\c", "C:\\a\\b\\c\\..\\d"), content="..\\d")
  inspect(relative("C:\\a\\b\\c\\..\\d", "C:\\a\\b\\c"), content="..\\c")

  // Mixed case drives (Windows is case-insensitive, but let's test)
  inspect(relative("c:\\temp", "C:\\temp\\file"), content="")
  inspect(relative("C:\\TEMP", "c:\\temp\\FILE"), content="")
}

///|
test "resolve edge cases" {
  // Already absolute paths should be normalized
  inspect(resolve("C:\\a\\.\\b"), content="C:\\a\\b")
  inspect(resolve("C:\\a\\..\\b"), content="C:\\b")
  inspect(resolve("C:\\a\\b\\..\\..\\c"), content="C:\\c")

  // UNC paths
  inspect(
    resolve("\\\\server\\share\\.\\file"),
    content="\\\\server\\share\\file",
  )
  inspect(
    resolve("\\\\server\\share\\folder\\..\\file"),
    content="\\\\server\\share\\file",
  )

  // Relative paths with current drive
  // Note: These tests assume we're running on Windows with a current drive
  // In cross-platform testing, these might need to be conditional

  // Verbatim paths
  inspect(resolve("\\\\?\\C:\\temp\\.\\file"), content="\\\\?\\C:\\temp\\file")
}

///|
test "constants and separators" {
  // Test delimiter constant (semicolon on Windows)
  inspect(delimiter, content=";")

  // Test separator constant (backslash on Windows)
  inspect(sep, content="\\")
}

///|
test "Windows-specific path behaviors" {
  // Test case insensitivity awareness (functions should handle but preserve case)
  inspect(basename("C:\\Temp\\File.TXT"), content="File.TXT")
  inspect(dirname("C:\\TEMP\\file.txt"), content="C:\\TEMP")
  inspect(extname("FILE.EXE"), content=".EXE")

  // Test with forward slashes (should not be treated as separators in Windows paths)
  inspect(basename("C:/temp/file"), content="C:/temp/file") // Whole string since no backslash
  inspect(dirname("C:/temp/file"), content="") // No backslash found

  // Test drive letter edge cases
  @json.inspect(is_absolute("A:"), content=false) // Relative to current dir on drive A
  @json.inspect(is_absolute("Z:\\"), content=true) // Root of drive Z
  inspect(join("C:", "temp"), content="C:\\temp") // Relative path on drive C
  inspect(join("C:\\", "temp"), content="C:\\temp") // Absolute path on drive C

  // Test UNC path components
  inspect(basename("\\\\server\\share"), content="share")
  inspect(dirname("\\\\server\\share"), content="\\\\server")
  inspect(dirname("\\\\server"), content="\\")

  // Test verbatim path handling
  inspect(basename("\\\\?\\C:\\very\\long\\path\\file"), content="file")
  inspect(
    dirname("\\\\?\\C:\\very\\long\\path\\file"),
    content="\\\\?\\C:\\very\\long\\path",
  )

  // Test device namespace paths
  inspect(basename("\\\\.\\COM1"), content="COM1")
  inspect(dirname("\\\\.\\COM1"), content="\\\\.")
}

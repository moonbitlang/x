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
/// Terminology:
/// 
/// path component is original from [posix 4.13 pathname resolution](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html#tag_04_13)

///|
let is_windows : Bool = @ffi.is_windows()

///|
/// Returns the last path component of the given path.
///
/// property: `@path.join(@path.dirname(path), @path.basename(path)) == path`
/// 
/// Warning: basename function not respect this POSIX standard, but consistent with Python `os.path` module.
/// 
pub fn basename(path : StringView) -> StringView {
  if is_windows {
    @win32.basename(path)
  } else {
    @posix.basename(path)
  }
}

///|
/// Returns path without its last path component and trailing slashes.
/// 
/// property: `@path.join(@path.dirname(path), @path.basename(path)) == path`
/// 
/// Warning: basename function not respect this POSIX standard, but consistent with Python `os.path` module.
/// 
pub fn dirname(path : StringView) -> StringView {
  if is_windows {
    @win32.dirname(path)
  } else {
    @posix.dirname(path)
  }
}

///|
/// Returns the string of the basename after the last `.` delimiter.
pub fn extname(path : StringView) -> StringView {
  if is_windows {
    @win32.extname(path)
  } else {
    @posix.extname(path)
  }
}

///|
/// Returns whether the given path is absolute.
/// 
/// edge cases: when path is empty, return false
pub fn is_absolute(path : StringView) -> Bool {
  if is_windows {
    @win32.is_absolute(path)
  } else {
    @posix.is_absolute(path)
  }
}

///|
/// 1. string concatenation with OS platform specific path separator
/// 2. if rhs is absolute path, return rhs normalized.
/// 
/// edge cases:
///  1. when lhs and rhs both are empty, return empty string
///  2. ignore empty string
pub fn join(lhs : StringView, rhs : StringView) -> StringView {
  if is_windows {
    @win32.join(lhs, rhs)
  } else {
    @posix.join(lhs, rhs)
  }
}

///|
/// 1. resolve `.` by directly removing it
/// 2. resolve `..` by removing the preceding path component if exists, otherwise keep it.
/// 3. remove redundant slashes or backslashes
/// 4. preserve trailing slash or backslash
/// 
/// edge cases:
///   1. when path is empty, return empty string
///   2. when path is contains two leading forward slashes like `//`, return `//`. respect POSIX standard, this behavior is inconsistent with Node.js path module.
/// 
pub fn normalize(path : StringView) -> StringView {
  if is_windows {
    @win32.normalize(path)
  } else {
    @posix.normalize(path)
  }
}

///|
/// Return the `to` relative path when `from` is the current working directory.
/// 
/// property: `@path.join(from,@path.relative(from,to)) == @path.normalize(to)`
/// 
/// edge cases: 
///  1. when `@path.normalize(from) == @path.normalize(to)`, return empty string
///  2. when `from` and `to` have different prefixes, return empty string
/// 
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn relative(from : StringView, to : StringView) -> StringView {
  if is_windows {
    @win32.relative(from, to)
  } else {
    @posix.relative(from, to)
  }
}

///|
/// 1. if path is already absolute, return path normalized.
/// 2. if path is relative, join current working directory and path, and then normalize it.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn resolve(path : StringView) -> StringView {
  if is_windows {
    @win32.resolve(path)
  } else {
    @posix.resolve(path)
  }
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = if is_windows { ';' } else { ':' }

///|
/// OS platform specific path component separator.
pub let sep : Char = if is_windows { '\\' } else { '/' }

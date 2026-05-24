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
/// A newtype wrapper provide path operation methods.
pub(all) struct Path(String) derive(Eq)

///|
pub impl Show for Path with fn output(path, logger) {
  logger.write_object(path.0)
}

///|
pub impl Show for Path with fn to_string(path) {
  path.0
}

///|
/// Returns the last path component of the given path.
///
/// Uses Python `ntpath.split()` semantics, where both `\` and `/` are separators.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr\\local\\bin"
///   inspect(path.basename(), content="bin")
/// }
/// ```
pub fn Path::basename(path : Path) -> StringView {
  nt_split(path.0).tail
}

///|
/// Returns path without its last path component and trailing separators.
///
/// Uses Python `ntpath.split()` semantics, where both `\` and `/` are separators.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr\\local\\bin"
///   inspect(path.dirname(), content="usr\\local")
/// }
/// ```
pub fn Path::dirname(path : Path) -> Path {
  nt_split(path.0).head
}

///|
/// Returns the extension part using Python `ntpath.splitext(path)[1]` semantics.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "archive.tar.gz"
///   inspect(path.extname(), content=".gz")
/// }
/// ```
pub fn Path::extname(path : Path) -> StringView {
  nt_splitext_ext(path.0)
}

///|
/// Returns whether the given path is absolute.
/// 
/// A `\\?\` prefix is absolute; otherwise the post-drive path must start with
/// `\` or `/`. Empty paths, drive-relative paths, and UNC/device roots without
/// a remaining root marker return false.
/// 
/// ```moonbit check
/// test {
///   let path1 : Path = "C:\\Program Files\\App"
///   let path2 : Path = "Program Files\\App"
///   json_inspect(path1.is_absolute(), content=true)
///   json_inspect(path2.is_absolute(), content=false)
/// }
/// ```
pub fn Path::is_absolute(path : Path) -> Bool {
  let path = path.0
  if path.replace_all(old="/", new="\\").has_prefix("\\\\?\\") {
    true
  } else {
    let split = nt_splitdrive(path)
    !split.rest.is_empty() && nt_starts_with_sep(split.rest)
  }
}

///|
/// Joins two path strings using Python `ntpath.join(lhs, rhs)` single-step
/// semantics. Drive-relative paths such as `C:temp` stay drive-relative, and an
/// empty rhs preserves Python's trailing-separator behavior.
/// 
/// ```moonbit check
/// test {
///   let path1 : Path = "C:\\Program Files"
///   let path2 : Path = "App"
///   inspect(path1.join(path2), content="C:\\Program Files\\App")
/// }
/// ```
pub fn Path::join(lhs : Path, rhs : Path) -> Path {
  nt_join2(lhs.0, rhs.0)
}

///|
/// Normalizes with Python `ntpath.normpath` string rules: `/` becomes `\`, an
/// empty relative result becomes `.`, and `\\?\` / `\\.\` special prefixes are
/// returned unchanged.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "C:\\usr\\\\local\\..\\bin\\"
///   inspect(path.normalize(), content="C:\\usr\\bin")
/// }
/// ```
pub fn Path::normalize(path : Path) -> Path {
  nt_normpath(path.0)
}

///|
/// Return the `to` relative path when `from` is the current working directory.
/// 
/// property: when `relative` does not return the compatibility exception `""`,
/// `@path.normalize(@path.join(from,@path.relative(from,to))) == @path.normalize(to)`
/// 
/// edge cases: 
///  1. when `@path.normalize(from) == @path.normalize(to)`, return `.`
///  2. when `from` and `to` have different drives/prefixes, return empty string
///  3. when `to` is empty, return empty string
/// 
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "C:\\Users\\Alice\\Documents\\Project"
///   let base : Path = "C:\\Users\\Alice"
///   inspect(path.relative(base~), content="Documents\\Project")
/// }
/// ```
pub fn Path::relative(path : Path, base~ : Path) -> Path {
  nt_relpath(path.0, base.0)
}

///|
/// 1. if path is absolute, return path normalized.
/// 2. if path is relative, join current working directory and path, and then normalize it.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
/// 
/// ```moonbit skip nocheck
/// let path : Path = "Documents\\Project"
/// inspect(path.resolve(), content="C:\\your\\current_working_directory\\Documents\\Project")
/// ```
pub fn Path::resolve(path : Path) -> Path {
  if Path::is_absolute(path) {
    Path::normalize(path)
  } else {
    Path::join(@env.current_dir().unwrap(), path) |> Path::normalize
  }
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = if true { ';' } else { ':' }

///|
/// OS platform specific path component separator.
pub let sep : Char = if true { '\\' } else { '/' }

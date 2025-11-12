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
/// Returns the last path component of the given path.
///
/// property: `@path.join(@path.dirname(path), @path.basename(path)) == path`
/// 
/// Warning: basename function not respect this POSIX standard, but consistent with Python `os.path` module.
/// 
pub fn basename(path : StringView) -> StringView {
  match path.rev_find("/") {
    None => path.to_string()
    Some(idx) if idx >= path.length() => ""
    Some(idx) => try! path[idx + 1:].to_string()
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
  let last_slash_pos = path.rev_find("/")
  match last_slash_pos {
    None => ""
    Some(idx) => {
      let dirname_with_trailing_slashes = try! path[0:idx]
      let dirname_trim_end = dirname_with_trailing_slashes.trim_end(
        char_set="/",
      )
      if dirname_trim_end.is_empty() {
        dirname_with_trailing_slashes.to_string()
      } else {
        dirname_trim_end.to_string()
      }
    }
  }
}

///|
/// Returns the string of the basename after the last `.` delimiter.
pub fn extname(path : StringView) -> StringView {
  let basename = basename(path)
  match basename.rev_find(".") {
    None => ""
    Some(idx) => try! basename[idx:].to_string()
  }
}

///|
/// Returns whether the given path is absolute.
/// 
/// edge cases: when path is empty, return false
pub fn is_absolute(path : StringView) -> Bool {
  match path {
    ['/', ..] => true
    _ => false
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
  if is_absolute(rhs) {
    return rhs.to_string()
  } else {
    match lhs {
      [] => rhs.to_string()
      [.., '/'] as all => {
        let builder = StringBuilder::new()
        builder.write_stringview(all)
        builder.write_stringview(rhs)
        builder.to_string()
      }
      without_tailing_slashes => {
        let builder = StringBuilder::new()
        builder.write_stringview(without_tailing_slashes)
        builder.write_char('/')
        builder.write_stringview(rhs)
        builder.to_string()
      }
    }
  }
}

///|
/// 1. resolve `.` by directly removing it
/// 2. resolve `..` by removing the preceding path component if exists, otherwise keep it.
/// 3. remove redundant slashes 
/// 4. preserve trailing slash
/// 
/// edge cases:
///   1. when path is empty, return empty string
///   2. when path is contains two leading forward slashes like `//`, return `//`. respect POSIX standard, this behavior is inconsistent with Node.js path module.
/// 
pub fn normalize(path : StringView) -> StringView {
  UnixPath::parse(path).to_string() catch {
    _ => path.to_string()
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
  let cwd = @env.current_dir().unwrap()
  let from = try! UnixPath::parse(join(cwd, from))
  let to = try! UnixPath::parse(join(cwd, to))
  if from.prefix == to.prefix {
    let mut cnt = 0
    // remove the common path component prefix
    loop (from.components[:], to.components[:]) {
      ([x, .. xs], [y, .. ys]) if x == y => {
        cnt += 1
        continue (xs, ys)
      }
      _ => ()
    }
    let components : Array[StringView] = []
    let goto_parent_cnt = from.components.length() - cnt
    for _ in 0..<goto_parent_cnt {
      components.push("..")
    }
    let rest_path = to.components[cnt:]
    for comp in rest_path {
      components.push(comp)
    }
    let path = UnixPath::{ prefix: None, components }
    path.to_string()
  } else {
    ""
  }
}

///|
/// 1. if path is already absolute, return path normalized.
/// 2. if path is relative, join current working directory and path, and then normalize it.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn resolve(path : StringView) -> StringView {
  if is_absolute(path) {
    normalize(path)
  } else {
    join(@env.current_dir().unwrap(), path)
  }
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = ':'

///|
/// OS platform specific path component separator.
pub let sep : Char = '/'

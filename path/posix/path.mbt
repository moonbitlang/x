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
pub(all) struct Path(String) derive(Eq, Debug)

///|
fn is_posix_sep_at(path : String, index : Int) -> Bool {
  path.get_char(index) == Some('/')
}

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
/// This follows Node `path.posix.basename`: trailing separators are ignored and
/// repeated separators are not normalized before scanning.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr/local/"
///   inspect(path.basename(), content="local")
/// }
/// ```
pub fn Path::basename(path : Path) -> StringView {
  let path = path.0
  let mut start = 0
  let mut end = -1
  let mut matched_slash = true
  for i = path.length() - 1; i >= 0; i = i - 1 {
    if is_posix_sep_at(path, i) {
      if !matched_slash {
        start = i + 1
        break
      }
    } else if end == -1 {
      matched_slash = false
      end = i + 1
    }
  }
  if end == -1 {
    ""
  } else {
    path[start:end]
  }
}

///|
/// Returns the directory portion of the given path.
///
/// This follows Node `path.posix.dirname`: it ignores trailing separators while
/// preserving repeated separators that participate in the directory portion.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr/local/"
///   inspect(path.dirname(), content="usr")
/// }
/// ```
pub fn Path::dirname(path : Path) -> Path {
  let path = path.0
  if path.is_empty() {
    return "."
  }
  let has_root = is_posix_sep_at(path, 0)
  let mut end = -1
  let mut matched_slash = true
  for i = path.length() - 1; i >= 1; i = i - 1 {
    if is_posix_sep_at(path, i) {
      if !matched_slash {
        end = i
        break
      }
    } else {
      matched_slash = false
    }
  }
  if end == -1 {
    if has_root {
      "/"
    } else {
      "."
    }
  } else if has_root && end == 1 {
    "//"
  } else {
    path[0:end].to_owned()
  }
}

///|
/// Returns the extension of the last path component.
///
/// This follows Node `path.posix.extname` dotfile rules: a leading dot by
/// itself does not start an extension.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "archive.tar.gz"
///   inspect(path.extname(), content=".gz")
/// }
/// ```
pub fn Path::extname(path : Path) -> StringView {
  let basename = Path::basename(path)
  if basename == "." || basename == ".." {
    return ""
  }
  match basename.rev_find(".") {
    None => ""
    Some(0) => ""
    Some(idx) => basename[idx:]
  }
}

///|
/// Returns whether the given path is absolute.
/// 
/// edge cases: when path is empty, return false
/// 
/// ```moonbit check
/// test {
///   let path1 : Path = "/usr/local/bin"
///   let path2 : Path = "usr/local/bin"
///   json_inspect(path1.is_absolute(), content=true)
///   json_inspect(path2.is_absolute(), content=false)
/// }
/// ```
pub fn Path::is_absolute(path : Path) -> Bool {
  let path = path.0
  match path {
    ['/', ..] => true
    _ => false
  }
}

///|
/// Concatenates two path strings with `/`, then normalizes the result.
///
/// Unlike `resolve`, an absolute right-hand path does not override `lhs`.
/// 
/// ```mbt check
/// test {
///   assert_eq(Path::join("/usr/local", "bin"), "/usr/local/bin")
///   assert_eq(Path::join("/usr/local", "/usr"), "/usr/local/usr")
///   assert_eq(Path::join("/usr/local", ""), "/usr/local")
///   assert_eq(Path::join("", "local/bin"), "local/bin")
///   assert_eq(Path::join("", ""), ".")
/// }
/// ```
pub fn Path::join(lhs : Path, rhs : Path) -> Path {
  let lhs = lhs.0
  let rhs = rhs.0
  if lhs.is_empty() && rhs.is_empty() {
    return "."
  }
  if lhs.is_empty() {
    return Path::normalize(rhs)
  }
  if rhs.is_empty() {
    return Path::normalize(lhs)
  }
  let builder = StringBuilder::new()
  builder.write_stringview(lhs)
  builder.write_char('/')
  builder.write_stringview(rhs)
  Path::normalize(builder.to_string())
}

///|
/// 1. resolve `.` by directly removing it
/// 2. resolve `..` by removing the preceding path component if exists, otherwise keep it.
/// 3. remove redundant slashes 
/// 4. preserve trailing slash
/// 
/// edge cases:
///   1. when path is empty, return `.`
///   2. leading `//` is normalized to `/`, following Node `path.posix`.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "/usr//local/../bin/"
///   inspect(path.normalize(), content="/usr/bin/")
/// }
/// ```
pub fn Path::normalize(path : Path) -> Path {
  UnixPath::parse(path.0).to_string()
}

///|
fn trim_resolved_trailing_separators(path : Path) -> Path {
  let raw = path.0
  if raw is [.. rest, lastchar] && lastchar == '/' && !rest.is_empty() {
    Path(rest.to_owned())
  } else {
    path
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
/// 
/// ```moonbit check
/// test {
///   let base : Path = "/usr/local/bin"
///   let path : Path = "/usr/local/share/doc"
///   inspect(path.relative(base~), content="../share/doc")
/// }
/// ```
pub fn Path::relative(path : Path, base~ : Path) -> Path {
  let from = UnixPath::parse(Path::resolve(base).0)
  let to = UnixPath::parse(Path::resolve(path).0)
  if from.prefix == to.prefix {
    let mut cnt = 0
    // remove the common path component prefix
    for left = from.components[:], right = to.components[:] {
      match (left, right) {
        ([x, .. xs], [y, .. ys]) if x == y => {
          cnt += 1
          continue xs, ys
        }
        _ => break
      }
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
    if components.is_empty() {
      ""
    } else {
      let path = UnixPath::{
        prefix: None,
        trailing_separator: false,
        components,
      }
      path.to_string()
    }
  } else {
    ""
  }
}

///|
/// 1. if path is already absolute, return path normalized.
/// 2. if path is relative, join current working directory and path, and then normalize it.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
/// 
pub fn Path::resolve(path : Path) -> Path {
  let resolved = if Path::is_absolute(path) {
    Path::normalize(path)
  } else {
    Path::join(@env.current_dir().unwrap(), path) |> Path::normalize
  }
  trim_resolved_trailing_separators(resolved)
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = ':'

///|
/// OS platform specific path component separator.
pub let sep : Char = '/'

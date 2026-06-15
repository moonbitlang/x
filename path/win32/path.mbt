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
fn is_ascii_alpha(ch : Char) -> Bool {
  match ch {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn is_win_sep(ch : Char) -> Bool {
  ch == '\\' || ch == '/'
}

///|
fn is_win_sep_at(path : String, index : Int) -> Bool {
  match path.get_char(index) {
    Some(ch) => is_win_sep(ch)
    None => false
  }
}

///|
fn has_win_drive(path : String) -> Bool {
  if path.length() < 2 || path.get_char(1) != Some(':') {
    false
  } else {
    match path.get_char(0) {
      Some(ch) => is_ascii_alpha(ch)
      _ => false
    }
  }
}

///|
fn find_next_win_sep(path : String, start : Int) -> Int? {
  for i = start; i < path.length(); i = i + 1 {
    if is_win_sep_at(path, i) {
      return Some(i)
    }
  }
  None
}

///|
fn skip_win_separators(path : String, start : Int) -> Int {
  let mut index = start
  while index < path.length() && is_win_sep_at(path, index) {
    index += 1
  }
  index
}

///|
fn win_root_end(path : String) -> Int {
  if path.is_empty() {
    return 0
  }
  if has_win_drive(path) {
    if path.length() > 2 && is_win_sep_at(path, 2) {
      return 3
    }
    return 2
  }
  if !is_win_sep_at(path, 0) {
    return 0
  }
  if path.length() == 1 || !is_win_sep_at(path, 1) {
    return 1
  }
  if path.length() > 2 && is_win_sep_at(path, 2) {
    return 1
  }
  let server_start = 2
  guard server_start < path.length() else { return 1 }
  match find_next_win_sep(path, server_start) {
    None => 1
    Some(server_end) => {
      let share_start = skip_win_separators(path, server_end)
      guard share_start < path.length() else { return 1 }
      match find_next_win_sep(path, share_start) {
        None => path.length()
        Some(share_end) => share_end + 1
      }
    }
  }
}

///|
fn is_drive_relative(path : String) -> Bool {
  has_win_drive(path) && (path.length() == 2 || !is_win_sep_at(path, 2))
}

///|
fn current_dir_for_drive(device : StringView) -> String {
  let device = device.to_owned()
  let cwd = match @env.get_env_var("=" + device) {
    Some(dir) => dir
    None => @env.current_dir().unwrap()
  }
  if has_win_drive(cwd) &&
    !cwd[0:2].equal_ignore_ascii_case(device) &&
    cwd.length() > 2 &&
    is_win_sep_at(cwd, 2) {
    device + "\\"
  } else if !has_win_drive(cwd) && cwd.length() > 0 && is_win_sep_at(cwd, 0) {
    device + cwd
  } else if !has_win_drive(cwd) {
    device + "\\" + cwd
  } else {
    cwd
  }
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
/// This follows Node `path.win32.basename`: both `/` and `\` are separators,
/// trailing separators are ignored, and root-only paths return an empty name.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr\\local\\"
///   inspect(path.basename(), content="local")
/// }
/// ```
pub fn Path::basename(path : Path) -> StringView {
  let path = path.0
  let root_end = if has_win_drive(path) { 2 } else { 0 }
  let mut start = root_end
  let mut end = -1
  let mut matched_sep = true
  for i = path.length() - 1; i >= root_end; i = i - 1 {
    if is_win_sep_at(path, i) {
      if !matched_sep {
        start = i + 1
        break
      }
    } else if end == -1 {
      matched_sep = false
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
/// This follows Node `path.win32.dirname`: both separators are recognized and
/// the returned directory preserves the original separator spelling.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "usr\\local\\"
///   inspect(path.dirname(), content="usr")
/// }
/// ```
pub fn Path::dirname(path : Path) -> Path {
  let path = path.0
  if path.is_empty() {
    return "."
  }
  let root_end = win_root_end(path)
  if root_end >= path.length() {
    return path
  }
  let mut end = -1
  let mut matched_sep = true
  for i = path.length() - 1; i >= root_end; i = i - 1 {
    if is_win_sep_at(path, i) {
      if !matched_sep {
        end = i
        break
      }
    } else {
      matched_sep = false
    }
  }
  if end == -1 {
    if root_end > 0 {
      path[0:root_end].to_owned()
    } else {
      "."
    }
  } else if end < root_end {
    path[0:root_end].to_owned()
  } else {
    path[0:end].to_owned()
  }
}

///|
test {
  let path : Path = "\\\\\\"
  inspect(path.prefix(), content="\\\\\\")
  // inspect(path.0.view)
}

///|
/// Returns the extension of the last path component.
///
/// This follows Node `path.win32.extname` dotfile rules.
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
///   let path1 : Path = "C:\\Program Files\\App"
///   let path2 : Path = "Program Files\\App"
///   json_inspect(path1.is_absolute(), content=true)
///   json_inspect(path2.is_absolute(), content=false)
/// }
/// ```
pub fn Path::is_absolute(path : Path) -> Bool {
  let path = path.0
  if path.is_empty() {
    false
  } else if is_win_sep_at(path, 0) {
    true
  } else {
    has_win_drive(path) && path.length() > 2 && is_win_sep_at(path, 2)
  }
}

///|
fn Path::prefix(path : Path) -> StringView {
  let path = path.0
  lexmatch path with longest {
    (("\\\\\?\\" ("[^\\]+" as _symlink) "(\\)+") as prefix, _rest) => prefix
    (
      (
        "\\\\\?UNC\\"
        ("[^\\]+" as _hostname)
        "\\"
        ("[^\\]+" as _shared_folder)
        "(\\)+"
      ) as prefix,
      _rest
    ) => prefix
    (
      ("\\\\" ("[^\\]+" as _hostname) "\\" ("[^\\]+" as _shared_folder) "(\\)*") as prefix,
      _rest
    ) => prefix
    (("\\\\\?\\Volume[{]" ("[^}]+" as _guid) "[}]") as prefix, _rest) => prefix
    (("\\\\\.\\" ("[^\\]+" as _device) "(\\)+") as prefix, _rest) => prefix
    (("\\\\\?\\" ("[a-zA-Z]" as _letter) ":(\\)+") as prefix, _rest) => prefix
    ("\\+" as prefix, _rest) => prefix
    ((("[a-zA-Z]" as _letter) ":(\\)+") as prefix, _rest) => prefix
    ((("[a-zA-Z]" as _letter) ":") as prefix, _rest) => prefix
    ("[^a-zA-Z\\][^:][^\\]+(\\)+" as prefix, _rest) => prefix
    _ => ""
  }
}

///|
fn join_rest(lhs : StringView, rhs : StringView) -> StringView? {
  lexmatch rhs with longest {
    ("\\\\\?\\" ("[^\\]+" as _symlink) "(\\)+", _rest) => None
    (
      "\\\\\?UNC\\"
      ("[^\\]+" as _hostname)
      "\\"
      ("[^\\]+" as _shared_folder)
      "(\\)+",
      _rest
    ) => None
    (
      "\\\\"
      ("[^\\]+" as _hostname)
      "\\"
      ("[^\\]+" as _shared_folder)
      "(\\)+",
      _rest
    ) => None
    ("\\\\\?\\Volume[{]" ("[^}]+" as _guid) "[}]", _rest) => None
    ("\\\\\.\\" ("[^\\]+" as _device) "(\\)+", _rest) => None
    ("\\\\\?\\" ("[a-zA-Z]" as _letter) ":(\\)+", _rest) => None
    ("\\", _rest) => None
    (("[a-zA-Z]" as _letter) ":(\\)+", _rest) => None
    (("[a-zA-Z]" as rhs_letter) ":", rhs_rest) =>
      lexmatch lhs with longest {
        (("[a-zA-Z]" as lhs_letter) ":", _rest) =>
          if lhs_letter == rhs_letter {
            Some(rhs_rest)
          } else {
            None
          }
        _ => None
      }
    ("[^a-zA-Z\\][^:][^\\]+(\\)+", _rest) => None
    rhs_rest => Some(rhs_rest)
  }
}

///|
/// Concatenates two path strings with `\`, then normalizes the result.
///
/// Absolute right-hand paths and different-drive paths do not override `lhs`.
/// 
/// ```moonbit check
/// test {
///   let path1 : Path = "C::\\Program Files"
///   let path2 : Path = "App"
///   inspect(path1.join(path2), content="C::\\Program Files\\App")
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
  builder.write_char('\\')
  builder.write_stringview(rhs)
  Path::normalize(builder.to_string())
}

///|
/// 1. resolve `.` by directly removing it
/// 2. resolve `..` by removing the preceding path component if exists, otherwise keep it.
/// 3. remove redundant backslashes 
/// 4. preserve trailing slash or backslash
/// 
/// edge cases:
///   1. when path is empty, return `.`
/// 
/// ```moonbit check
/// test {
///   let path : Path = "C:\\usr\\\\local\\..\\bin\\"
///   inspect(path.normalize(), content="C:\\usr\\bin\\")
///
///   let rooted_path : Path = "/usr//local/../bin/"
///   inspect(rooted_path.normalize(), content="\\usr\\bin\\")
/// }
/// ```
pub fn Path::normalize(path : Path) -> Path {
  WinPath::parse(path.0).to_string()
}

///|
fn is_regular_win_root(path : WinPath) -> Bool {
  if path.components.is_empty() {
    match path.prefix {
      Root | VolumeLetterRoot(_) | UNC(_) => true
      _ => false
    }
  } else {
    false
  }
}

///|
fn trim_resolved_trailing_separators(path : Path) -> Path {
  let parsed = WinPath::parse(path.0)
  if is_regular_win_root(parsed) {
    return path
  }
  let raw = path.0
  if raw is [.. rest, lastchar] && is_win_sep(lastchar) {
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
///  2. when roots differ, return the resolved target path
/// 
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
/// 
/// ```moonbit check
/// test {
///   let path : Path = "C:\\Users\\Alice\\Documents\\Project"
///   let base : Path = "C:\\Users\\Alice"
///   inspect(path.relative(base~), content="Documents\\Project")
///
///   let base : Path = "/usr/local/bin"
///   let path : Path = "/usr/local/share/doc"
///   inspect(path.relative(base~), content="..\\share\\doc")
/// }
/// ```
pub fn Path::relative(path : Path, base~ : Path) -> Path {
  let resolved_from = Path::resolve(base)
  let resolved_to = Path::resolve(path)
  let from = WinPath::parse(resolved_from.0)
  let to = WinPath::parse(resolved_to.0)
  if from.prefix.to_string().equal_ignore_ascii_case(to.prefix.to_string()) {
    let mut cnt = 0
    // remove the common path component prefix
    for left = from.components[:], right = to.components[:] {
      match (left, right) {
        ([x, .. xs], [y, .. ys]) if x.equal_ignore_ascii_case(y) => {
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
      let path = WinPath::{
        prefix: None,
        trailing_separator: false,
        components,
      }
      path.to_string()
    }
  } else {
    resolved_to
  }
}

///|
/// 1. if path is absolute, return path normalized.
/// 2. if path is relative, join current working directory and path, and then normalize it.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn Path::resolve(path : Path) -> Path {
  let raw_path = path.0
  let resolved = if Path::is_absolute(path) {
    Path::normalize(path)
  } else if is_drive_relative(raw_path) {
    let base = Path::normalize(current_dir_for_drive(raw_path[0:2]))
    let tail = raw_path[2:]
    if tail.is_empty() {
      base
    } else {
      Path::join(base, tail.to_owned()) |> Path::normalize
    }
  } else {
    Path::join(@env.current_dir().unwrap(), path) |> Path::normalize
  }
  trim_resolved_trailing_separators(resolved)
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = if true { ';' } else { ':' }

///|
/// OS platform specific path component separator.
pub let sep : Char = if true { '\\' } else { '/' }

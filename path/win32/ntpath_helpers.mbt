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
/// Split result for Windows drive and share prefixes.
///
/// `drive` contains the parsed drive, UNC share, or device-like prefix. `rest`
/// is the remaining path text that should still be interpreted as path
/// components.
priv struct NtDriveSplit {
  drive : StringView
  rest : StringView
}

///|
/// Split result for directory/head and basename/tail operations.
///
/// `head` owns its string because it may be rebuilt from a drive prefix and a
/// trimmed directory component. `tail` is a view into the original path.
priv struct NtPathSplit {
  head : String
  tail : StringView
}

///|
/// Returns true for either separator accepted by Windows path APIs.
fn nt_is_sep(ch : Char) -> Bool {
  ch == '\\' || ch == '/'
}

///|
/// Option-aware separator check used by parsers that may probe past the end of
/// short paths.
fn nt_is_sep_opt(ch : Char?) -> Bool {
  match ch {
    Some(ch) => nt_is_sep(ch)
    None => false
  }
}

///|
/// Returns whether the path begins with either Windows separator spelling.
fn nt_starts_with_sep(path : StringView) -> Bool {
  match path {
    ['\\', ..] | ['/', ..] => true
    _ => false
  }
}

///|
/// Returns whether the path begins with a canonical Windows backslash.
fn nt_starts_with_backslash(path : StringView) -> Bool {
  match path {
    ['\\', ..] => true
    _ => false
  }
}

///|
/// Returns whether the path ends with either Windows separator spelling.
fn nt_ends_with_sep(path : StringView) -> Bool {
  match path {
    [.., '\\'] | [.., '/'] => true
    _ => false
  }
}

///|
/// Returns whether the path ends in a drive separator colon.
fn nt_ends_with_colon(path : StringView) -> Bool {
  match path {
    [.., ':'] => true
    _ => false
  }
}

///|
/// Finds the first Windows separator at or after `start`.
///
/// Returns `None` when no slash or backslash exists in that suffix.
fn nt_find_sep_from(path : StringView, start : Int) -> Int? {
  for i, ch in path {
    if i >= start && nt_is_sep(ch) {
      return Some(i)
    }
  }
  None
}

///|
/// Returns the last slash or backslash index, or `-1` when none is present.
fn nt_last_sep_index(path : StringView) -> Int {
  let mut index = -1
  match path.rev_find("\\") {
    Some(i) => index = i
    None => ()
  }
  match path.rev_find("/") {
    Some(i) if i > index => index = i
    _ => ()
  }
  index
}

///|
/// Removes trailing Windows separators from a path view.
///
/// Callers that need to preserve a root separator should decide that after
/// seeing whether the trimmed view became empty.
fn nt_rstrip_seps(path : StringView) -> StringView {
  let mut end = path.length()
  for ;; {
    if end <= 0 {
      break
    }
    match path[:end] {
      [.., '\\'] | [.., '/'] => end -= 1
      _ => break
    }
  }
  path[:end]
}

///|
/// Removes leading backslashes after a rooted prefix has already been recorded.
fn nt_lstrip_backslashes(path : StringView) -> StringView {
  for i, ch in path {
    if ch != '\\' {
      return path[i:]
    }
  }
  ""
}

///|
/// Normalizes a path string for case-insensitive Windows comparisons.
///
/// Forward slashes are converted to backslashes before lowercasing so equivalent
/// drive prefixes compare equal.
fn nt_normcase(path : StringView) -> String {
  path.to_owned().replace_all(old="/", new="\\").to_lower()
}

///|
/// Splits off the Windows drive/share prefix using Python `ntpath.splitdrive`
/// rules.
///
/// Recognized prefixes include drive letters such as `C:` and UNC shares such
/// as `\\server\share`. Malformed UNC-like inputs are left entirely in `rest`
/// to match `ntpath` compatibility behavior.
fn nt_splitdrive(path : StringView) -> NtDriveSplit {
  if path.length() >= 2 {
    if nt_is_sep_opt(path.get_char(0)) &&
      nt_is_sep_opt(path.get_char(1)) &&
      !nt_is_sep_opt(path.get_char(2)) {
      match nt_find_sep_from(path, 2) {
        None => NtDriveSplit::{ drive: "", rest: path }
        Some(index) =>
          match nt_find_sep_from(path, index + 1) {
            Some(index2) if index2 == index + 1 =>
              NtDriveSplit::{ drive: "", rest: path }
            Some(index2) =>
              NtDriveSplit::{ drive: path[:index2], rest: path[index2:] }
            None => NtDriveSplit::{ drive: path[:], rest: path[path.length():] }
          }
      }
    } else {
      match path.get_char(1) {
        Some(':') => NtDriveSplit::{ drive: path[:2], rest: path[2:] }
        _ => NtDriveSplit::{ drive: "", rest: path }
      }
    }
  } else {
    NtDriveSplit::{ drive: "", rest: path }
  }
}

///|
/// Splits a path into directory head and basename tail.
///
/// This follows Python `ntpath.split`: the drive/share prefix stays with
/// `head`, trailing separators are removed from the directory part, and the
/// final component remains as a view into the original path.
fn nt_split(path : StringView) -> NtPathSplit {
  let split = nt_splitdrive(path)
  let last_sep = nt_last_sep_index(split.rest)
  let split_at = last_sep + 1
  let head = split.rest[:split_at]
  let tail = split.rest[split_at:]
  let trimmed_head = nt_rstrip_seps(head)
  let final_head = if trimmed_head.is_empty() { head } else { trimmed_head }
  let builder = StringBuilder::new()
  builder.write_stringview(split.drive)
  builder.write_stringview(final_head)
  NtPathSplit::{ head: builder.to_string(), tail }
}

///|
/// Returns the extension slice according to Python `ntpath.splitext`.
///
/// Dots that are part of a leading-dot basename prefix do not start an
/// extension, so `.profile` and `...profile` return an empty extension.
fn nt_splitext_ext(path : StringView) -> StringView {
  let sep_index = nt_last_sep_index(path)
  let dot_index = match path.rev_find(".") {
    Some(i) => i
    None => return ""
  }
  if dot_index > sep_index {
    let mut filename_index = sep_index + 1
    for ;; {
      if filename_index >= dot_index {
        break
      }
      if path[filename_index:filename_index + 1] != "." {
        return path[dot_index:]
      }
      filename_index += 1
    }
  }
  ""
}

///|
/// Returns whether `nt_normpath` should leave the path unchanged.
///
/// Verbatim and device namespace paths are passed through because Windows treats
/// their contents differently from ordinary paths.
fn nt_is_special_normpath(path : StringView) -> Bool {
  path.has_prefix("\\\\.\\") || path.has_prefix("\\\\?\\")
}

///|
/// Normalizes a Windows path using Python `ntpath.normpath` string semantics.
///
/// The normalization converts `/` to `\`, resolves `.` and `..` components where
/// possible, preserves rooted prefixes, and returns `.` for an empty relative
/// result.
fn nt_normpath(path : StringView) -> String {
  if nt_is_special_normpath(path) {
    return path.to_owned()
  }
  let path = path.to_owned().replace_all(old="/", new="\\")
  let split = nt_splitdrive(path)
  let mut prefix = split.drive.to_owned()
  let mut rest = split.rest
  if nt_starts_with_backslash(rest) {
    prefix = prefix + "\\"
    rest = nt_lstrip_backslashes(rest)
  }
  let components : Array[StringView] = []
  for comp in rest.split("\\") {
    if comp.is_empty() || comp == "." {
      continue
    } else if comp == ".." {
      match components.last() {
        Some("..") => components.push(comp)
        Some(_) => ignore(components.pop())
        None =>
          if nt_ends_with_sep(prefix) {
            ()
          } else {
            components.push(comp)
          }
      }
    } else {
      components.push(comp)
    }
  }
  if prefix.is_empty() && components.is_empty() {
    components.push(".")
  }
  prefix + components.join("\\")
}

///|
/// Joins two path fragments using one step of Python `ntpath.join`.
///
/// Absolute right-hand paths replace the left-hand path, drive-relative paths
/// keep their drive semantics, and same-drive comparisons are case-insensitive.
fn nt_join2(lhs : StringView, rhs : StringView) -> String {
  let lhs_split = nt_splitdrive(lhs)
  let mut result_drive = lhs_split.drive.to_owned()
  let mut result_path = lhs_split.rest.to_owned()
  let rhs_split = nt_splitdrive(rhs)
  let rhs_drive = rhs_split.drive
  let rhs_path = rhs_split.rest
  if !rhs_path.is_empty() && nt_starts_with_sep(rhs_path) {
    if !rhs_drive.is_empty() || result_drive.is_empty() {
      result_drive = rhs_drive.to_owned()
    }
    result_path = rhs_path.to_owned()
  } else if !rhs_drive.is_empty() && rhs_drive.to_owned() != result_drive {
    if nt_normcase(rhs_drive) != nt_normcase(result_drive) {
      result_drive = rhs_drive.to_owned()
      result_path = rhs_path.to_owned()
    } else {
      result_drive = rhs_drive.to_owned()
      if !result_path.is_empty() && !nt_ends_with_sep(result_path) {
        result_path = result_path + "\\"
      }
      result_path = result_path + rhs_path.to_owned()
    }
  } else {
    if !result_path.is_empty() && !nt_ends_with_sep(result_path) {
      result_path = result_path + "\\"
    }
    result_path = result_path + rhs_path.to_owned()
  }
  if !result_path.is_empty() &&
    !nt_starts_with_sep(result_path) &&
    !result_drive.is_empty() &&
    !nt_ends_with_colon(result_drive) {
    result_drive + "\\" + result_path
  } else {
    result_drive + result_path
  }
}

///|
/// Splits a normalized backslash path into non-empty components.
fn nt_nonempty_backslash_components(path : StringView) -> Array[StringView] {
  let components : Array[StringView] = []
  for comp in path.split("\\") {
    if !comp.is_empty() {
      components.push(comp)
    }
  }
  components
}

///|
/// Computes a relative path from `start` to `path`.
///
/// Both inputs are normalized and resolved first. When the resolved drive/share
/// prefixes differ, this returns the empty string as the package's compatibility
/// fallback instead of raising an error.
fn nt_relpath(path : StringView, start : StringView) -> String {
  if path.is_empty() {
    return ""
  }
  let start_abs = Path::resolve(Path::normalize(start.to_owned())).0
  let path_abs = Path::resolve(Path::normalize(path.to_owned())).0
  let start_split = nt_splitdrive(start_abs)
  let path_split = nt_splitdrive(path_abs)
  if nt_normcase(start_split.drive) != nt_normcase(path_split.drive) {
    return ""
  }
  let start_list = nt_nonempty_backslash_components(start_split.rest)
  let path_list = nt_nonempty_backslash_components(path_split.rest)
  let mut count = 0
  for left = start_list[:], right = path_list[:] {
    match (left, right) {
      ([x, .. xs], [y, .. ys]) if nt_normcase(x) == nt_normcase(y) => {
        count += 1
        continue xs, ys
      }
      _ => break
    }
  }
  let rel_list : Array[StringView] = []
  for _ in 0..<(start_list.length() - count) {
    rel_list.push("..")
  }
  for comp in path_list[count:] {
    rel_list.push(comp)
  }
  if rel_list.is_empty() {
    "."
  } else {
    rel_list.join("\\")
  }
}

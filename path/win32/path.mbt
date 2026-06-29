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
  path.get_char(index) is Some('\\' | '/')
}

///|
fn start_with_win_drive(path : String) -> Bool {
  path is [ch, ':', ..] && is_ascii_alpha(ch)
}

///|
fn strip_win_drive(path : String) -> StringView {
  if path is [ch, ':', .. rest] && is_ascii_alpha(ch) {
    return rest
  } else {
    return path
  }
}

///|
fn last_win_sep(path : StringView) -> Int? {
  match (path.rev_find("/"), path.rev_find("\\")) {
    (None, None) => None
    (Some(idx), None) | (None, Some(idx)) => Some(idx)
    (Some(lidx), Some(ridx)) => Some(@cmp.maximum(lidx, ridx))
  }
}

///|
fn find_next_win_sep(path : String, start : Int) -> Int? {
  for i in start..<path.length() {
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
  if start_with_win_drive(path) {
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
  start_with_win_drive(path) && (path.length() == 2 || !is_win_sep_at(path, 2))
}

///|
fn current_dir_for_drive_with_cwd(
  device : StringView,
  fallback_cwd : String,
) -> String {
  let device = device.to_owned()
  let cwd = match @env.get_env_var("=" + device) {
    Some(dir) => dir
    None => fallback_cwd
  }
  if start_with_win_drive(cwd) &&
    !cwd[0:2].equal_ignore_ascii_case(device) &&
    cwd.length() > 2 &&
    is_win_sep_at(cwd, 2) {
    device + "\\"
  } else if !start_with_win_drive(cwd) &&
    cwd.length() > 0 &&
    is_win_sep_at(cwd, 0) {
    device + cwd
  } else if !start_with_win_drive(cwd) {
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
  // strip win drive
  let mut path = strip_win_drive(path.0)
  // strip all trailing separator
  while path is [.. rest, last_char] && is_win_sep(last_char) {
    path = rest
  }
  // return content after last separator
  match last_win_sep(path) {
    None => path
    Some(idx) => path[idx + 1:]
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
  let raw = path.0
  if raw.is_empty() {
    return "."
  }
  let root_end = win_root_end(raw)
  if root_end >= raw.length() {
    return raw
  }
  let mut path = raw[:]
  // strip all trailing separator outside the root
  while path.length() > root_end &&
        path is [.. rest, last_char] &&
        is_win_sep(last_char) {
    path = rest
  }
  if path.length() <= root_end {
    raw[0:root_end].to_owned()
  } else {
    match last_win_sep(path) {
      None => if root_end > 0 { raw[0:root_end].to_owned() } else { "." }
      Some(idx) =>
        if idx < root_end {
          raw[0:root_end].to_owned()
        } else {
          raw[0:idx].to_owned()
        }
    }
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
  match path.0 {
    [sep, ..] if is_win_sep(sep) => true
    [drive, ':', sep, ..] if is_ascii_alpha(drive) && is_win_sep(sep) => true
    _ => false
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
  let raw = path.0
  let normalized = WinPath::parse(raw).to_string()
  if needs_normalize_drive_guard(raw, normalized) {
    ".\\" + normalized
  } else {
    normalized
  }
}

///|
fn needs_normalize_drive_guard(raw : String, normalized : String) -> Bool {
  if Path::is_absolute(raw) ||
    start_with_win_drive(raw) ||
    !raw.contains_char(':') {
    return false
  }
  if start_with_win_drive(normalized) {
    return true
  }
  for i in 0..<raw.length() {
    if raw.get_char(i) == Some(':') &&
      (i == raw.length() - 1 || is_win_sep_at(raw, i + 1)) {
      return true
    }
  }
  false
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
  let mut raw = path.0[:]
  while raw is [.. rest, last_char] && is_win_sep(last_char) && !rest.is_empty() {
    raw = rest
  }
  Path(raw.to_owned())
}

///|
/// Return the `to` relative path when `from` is the current working directory.
/// 
/// property: joining `from` with the returned relative path yields
/// `@path.resolve(to)`.
/// 
/// edge cases: 
///  1. when `@path.resolve(from) == @path.resolve(to)`, return empty string
///  2. when resolved paths have no common root boundary, return the resolved target path
/// 
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
///
/// Known issue: Unicode case folding is incomplete. Some non-Latin paths that
/// Node treats as equal ignoring case may produce a relative path.
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
  relative_resolved_paths(resolved_from.0, resolved_to.0)
}

///|
fn win_char_to_common_lower(ch : Char) -> Char {
  match ch {
    'A'..='Z' => ch.to_ascii_lowercase()
    'À' => 'à'
    'Á' => 'á'
    'Â' => 'â'
    'Ã' => 'ã'
    'Ä' => 'ä'
    'Å' => 'å'
    'Æ' => 'æ'
    'Ç' => 'ç'
    'È' => 'è'
    'É' => 'é'
    'Ê' => 'ê'
    'Ë' => 'ë'
    'Ì' => 'ì'
    'Í' => 'í'
    'Î' => 'î'
    'Ï' => 'ï'
    'Ð' => 'ð'
    'Ñ' => 'ñ'
    'Ò' => 'ò'
    'Ó' => 'ó'
    'Ô' => 'ô'
    'Õ' => 'õ'
    'Ö' => 'ö'
    'Ø' => 'ø'
    'Ù' => 'ù'
    'Ú' => 'ú'
    'Û' => 'û'
    'Ü' => 'ü'
    'Ý' => 'ý'
    'Þ' => 'þ'
    'Ÿ' => 'ÿ'
    _ => ch
  }
}

///|
fn win_char_equal_ignore_case(left : Char, right : Char) -> Bool {
  win_char_to_common_lower(left) == win_char_to_common_lower(right)
}

///|
fn win_string_equal_ignore_case(left : String, right : String) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    guard (left.get_char(i), right.get_char(i)) is (Some(left), Some(right)) &&
      win_char_equal_ignore_case(left, right) else {
      return false
    }
  }
  true
}

///|
fn trim_leading_backslashes(path : String) -> Int {
  let mut start = 0
  while start < path.length() && path.get_char(start) == Some('\\') {
    start += 1
  }
  start
}

///|
fn trim_trailing_backslashes(path : String, start : Int) -> Int {
  let mut end = path.length()
  while end - 1 > start && path.get_char(end - 1) == Some('\\') {
    end -= 1
  }
  end
}

///|
fn write_parent_steps(
  builder : StringBuilder,
  from : String,
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<=end {
    if i == end || from.get_char(i) == Some('\\') {
      if builder.is_empty() {
        builder.write_stringview("..")
      } else {
        builder.write_stringview("\\..")
      }
    }
  }
}

///|
fn relative_resolved_paths(from_orig : String, to_orig : String) -> Path {
  if from_orig == to_orig || win_string_equal_ignore_case(from_orig, to_orig) {
    return ""
  }
  let from_start = trim_leading_backslashes(from_orig)
  let from_end = trim_trailing_backslashes(from_orig, from_start)
  let from_len = from_end - from_start
  let to_start = trim_leading_backslashes(to_orig)
  let to_end = trim_trailing_backslashes(to_orig, to_start)
  let to_len = to_end - to_start
  let length = @cmp.minimum(from_len, to_len)
  let mut last_common_sep = -1
  let mut i = 0
  while i < length {
    let from_char = from_orig.get_char(from_start + i).unwrap()
    let to_char = to_orig.get_char(to_start + i).unwrap()
    if !win_char_equal_ignore_case(from_char, to_char) {
      break
    } else if from_char == '\\' {
      last_common_sep = i
    }
    i += 1
  }
  if i != length {
    if last_common_sep == -1 {
      return to_orig
    }
  } else {
    if to_len > length {
      if to_orig.get_char(to_start + i) == Some('\\') {
        return to_orig[to_start + i + 1:to_end].to_owned()
      }
      if i == 2 {
        return to_orig[to_start + i:to_end].to_owned()
      }
    }
    if from_len > length {
      if from_orig.get_char(from_start + i) == Some('\\') {
        last_common_sep = i
      } else if i == 2 {
        last_common_sep = 3
      }
    }
    if last_common_sep == -1 {
      last_common_sep = 0
    }
  }
  let builder = StringBuilder::new()
  write_parent_steps(
    builder,
    from_orig,
    from_start + last_common_sep + 1,
    from_end,
  )
  let mut to_start = to_start + last_common_sep
  if !builder.is_empty() {
    builder.write_stringview(to_orig[to_start:to_end])
    return builder.to_string()
  }
  if to_orig.get_char(to_start) == Some('\\') {
    to_start += 1
  }
  to_orig[to_start:to_end].to_owned()
}

///|
/// 1. if path is absolute, normalize it and remove trailing separators except regular roots.
/// 2. if path is drive-relative, resolve it against that drive's current directory,
///    then normalize it and remove trailing separators except regular roots.
/// 3. if path is otherwise relative, join current working directory and path,
///    then normalize it and remove trailing separators except regular roots.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn Path::resolve(path : Path) -> Path {
  resolve_with_cwd(path, @env.current_dir().unwrap())
}

///|
fn cwd_has_win_drive_root(cwd : String) -> Bool {
  start_with_win_drive(cwd) && cwd.length() > 2 && is_win_sep_at(cwd, 2)
}

///|
fn resolve_with_cwd(path : Path, cwd : String) -> Path {
  let raw_path = path.0
  let parsed = WinPath::parse(raw_path)
  let resolved = match parsed.prefix {
    Root =>
      if cwd_has_win_drive_root(cwd) {
        Path::normalize(cwd[0:2].to_owned() + raw_path)
      } else {
        Path::normalize(path)
      }
    VolumeLetterRoot(_) | UNC(_) | VerbatimRoot | DeviceRoot =>
      Path::normalize(path)
    _ =>
      if is_drive_relative(raw_path) {
        let base = Path::normalize(
          current_dir_for_drive_with_cwd(raw_path[0:2], cwd),
        )
        let tail = raw_path[2:]
        if tail.is_empty() {
          base
        } else {
          Path::join(base, tail.to_owned()) |> Path::normalize
        }
      } else {
        Path::join(cwd, path) |> Path::normalize
      }
  }
  trim_resolved_trailing_separators(resolved)
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = if true { ';' } else { ':' }

///|
/// OS platform specific path component separator.
pub let sep : Char = if true { '\\' } else { '/' }

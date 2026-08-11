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
fn is_win_sep(ch : Char) -> Bool {
  ch == '\\' || ch == '/'
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
fn is_drive_relative(path : String) -> Bool {
  start_with_win_drive(path) && (path.length() == 2 || !is_win_sep_at(path, 2))
}

///|
/// Resolves the current directory of a drive-relative path, following
/// `GetFullPathNameW`: a drive-relative path such as `C:main.mbt` is relative
/// to the current directory of drive `C`, not to the process current
/// directory.
///
/// Windows stores the per-drive current directory in a hidden environment
/// variable named `=<L>:` (e.g. `=C:`), which a process inherits and updates
/// as the drive's current directory changes. When the variable is absent
/// (e.g. set by another process, or constructed by `SetCurrentDirectory`
/// semantics without one), `fallback_cwd` is used instead.
///
/// See [The Old New Thing: What are these environment variables like
/// =C:?](https://devblogs.microsoft.com/oldnewthing/20100412-00/?p=14313)
fn current_dir_for_drive_with_cwd(
  device : StringView,
  fallback_cwd : String,
) -> String {
  let device = device.to_owned()
  let cwd = @env.get_env_var("=\{device}").unwrap_or(fallback_cwd)
  if start_with_win_drive(cwd) &&
    !cwd[0:2].equal_ignore_ascii_case(device) &&
    cwd.length() > 2 &&
    is_win_sep_at(cwd, 2) {
    "\\\{device}"
  } else if !start_with_win_drive(cwd) &&
    cwd.length() > 0 &&
    is_win_sep_at(cwd, 0) {
    "\{device}\{cwd}"
  } else if !start_with_win_drive(cwd) {
    "\{device}\\\{cwd}"
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
  let mut path = path.0[:]
  if start_with_win_drive(path) {
    path = path[2:]
  }
  // strip all trailing separator
  let path = path.trim_end(chars="/\\")
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
  guard !raw.is_empty() else { "." }
  let root_end = WinPath::parse(raw).root_end
  guard root_end < raw.length() else { raw }
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
    None | Some(0) => ""
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
  match WinPath::parse(path.0).prefix {
    Root | VerbatimRoot | DeviceRoot | UNC(_) | VolumeLetterRoot(_) => true
    _ => false
  }
}

///|
/// Returns the root of the given path, following Node `path.win32.parse().root`.
///
/// The root keeps the input's separator spelling and includes the trailing
/// separator for rooted paths (e.g. `C:\`, `\\server\share\`, `\\?\C:\`).
/// A path without a root returns an empty string.
///
/// edge cases:
///   1. when path is empty or relative, return `""`
///   2. bare `\\` and UNC host without share return `\`, following Node
/// 
/// ```moonbit check
/// test {
///   let path : Path = "C:\\foo\\bar"
///   inspect(path.root(), content="C:\\")
///   let path : Path = "\\\\server\\share\\file"
///   inspect(path.root(), content="\\\\server\\share\\")
/// }
/// ```
pub fn Path::root(path : Path) -> StringView {
  path.0[:WinPath::parse(path.0).root_end]
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
  guard !lhs.is_empty() || !rhs.is_empty() else { "." }
  guard !lhs.is_empty() else { Path::normalize(rhs) }
  guard !rhs.is_empty() else { Path::normalize(lhs) }
  Path::normalize(lhs + "\\" + rhs)
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
  let parsed = WinPath::parse(raw)
  let normalized = Show::to_string(parsed)
  if needs_normalize_drive_guard(raw, normalized, parsed) {
    ".\\\{normalized}"
  } else {
    normalized
  }
}

///|
fn needs_normalize_drive_guard(
  raw : String,
  normalized : String,
  parsed : WinPath,
) -> Bool {
  guard parsed.prefix is None && raw.contains_char(':') else { return false }
  if start_with_win_drive(normalized) {
    return true
  }
  for i in 0..<raw.length() {
    guard raw.get_char(i) == Some(':') &&
      (i == raw.length() - 1 || is_win_sep_at(raw, i + 1)) else {
      continue
    }
    return true
  }
  false
}

///|
fn is_regular_win_root(path : WinPath) -> Bool {
  guard path.components.is_empty() else { false }
  match path.prefix {
    Root | VolumeLetterRoot(_) | UNC(_) => true
    _ => false
  }
}

///|
fn trim_resolved_trailing_separators(path : Path) -> Path {
  let parsed = WinPath::parse(path.0)
  guard !is_regular_win_root(parsed) else { path }
  let mut raw = path.0[:]
  while raw is [.. rest, last_char] && is_win_sep(last_char) && !rest.is_empty() {
    raw = rest
  }
  Path(raw.to_owned())
}

///|
/// Returns the relative path from `base` to `path`.
/// 
/// property: joining `base` with the returned relative path yields
/// `@path.resolve(path)`.
/// 
/// edge cases: 
///  1. when `@path.resolve(base) == @path.resolve(path)`, return empty string
///  2. when the resolved paths have no common root boundary, return the resolved target path
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
  guard i == length || last_common_sep != -1 else { return to_orig }
  if i == length {
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
/// 1. if path is fully rooted (drive root, UNC, verbatim, or device root),
///    normalize it and remove trailing separators except regular roots.
/// 2. if path is drive-less rooted, resolve it against the current drive or
///    UNC share when cwd provides one, then normalize it and remove trailing
///    separators except regular roots.
/// 3. if path is drive-relative, resolve it against that drive's current directory
///    (read from the `=<L>:` environment variable, following `GetFullPathNameW`),
///    then normalize it and remove trailing separators except regular roots.
/// 4. if path is otherwise relative, join current working directory and path,
///    then normalize it and remove trailing separators except regular roots.
///
/// Warning: cwd is already resolve symbolic link and normalized, but path doesn't.
pub fn Path::resolve(path : Path) -> Path {
  resolve_with_cwd(path, @env.current_dir().unwrap())
}

///|
fn cwd_device_for_drive_less_rooted_path(cwd : String) -> String? {
  match WinPath::parse(cwd).prefix {
    VolumeLetterRoot(_) => Some(cwd[0:2].to_owned())
    UNC(hostname~, shared_folder~) => Some("\\\\\{hostname}\\\{shared_folder}")
    _ => None
  }
}

///|
fn resolve_with_cwd(path : Path, cwd : String) -> Path {
  let raw_path = path.0
  let parsed = WinPath::parse(raw_path)
  let resolved = match parsed.prefix {
    Root =>
      match cwd_device_for_drive_less_rooted_path(cwd) {
        Some(device) => Path::normalize("\{device}\{raw_path}")
        None => Path::normalize(path)
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
          Path::join(base, tail.to_owned())
        }
      } else {
        Path::join(cwd, path)
      }
  }
  trim_resolved_trailing_separators(resolved)
}

///|
/// OS platform specific path delimiter for environment variables. e.g., PATH
pub let delimiter : Char = ';'

///|
/// OS platform specific path component separator.
pub let sep : Char = '\\'

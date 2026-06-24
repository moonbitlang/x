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
/// [Microsoft Naming a Volume](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-volume)
/// [Microsoft Naming Files, Paths, and Namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file)
/// [Microsoft Maximum Path Length Limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
priv struct WinPath {
  prefix : WinPrefix
  trailing_separator : Bool
  components : Array[StringView]
} derive(ToJson, Hash, Eq)

///|
/// 
/// #### Verbatim Prefix
/// 
/// refer to [Microsoft Win32 File Namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file#win32-file-namespaces)
/// > For file I/O,
/// > the "\\?\" prefix to a path string tells the Windows APIs to disable all string parsing and to send the string that follows it straight to the file system.
/// 
/// #### Windows Encoding 
/// 
/// refer to [Microsoft Path Unicode Normalization](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
/// 
/// > There is no need to perform any Unicode normalization on path and file name strings for use by the Windows file I/O API functions 
/// > because the file system treats path and file names as an opaque sequence of WCHARs.
/// > Any normalization that your application requires should be performed with this in mind, 
/// > external of any calls to related Windows file I/O API functions.
/// 
/// #### Relative Paths Cannot use Verbatim Prefix
/// 
/// refer to [Microsoft Verbatim restriction](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
/// 
/// > Because you cannot use the "\\?\" prefix with a relative path, 
/// > relative paths are always limited to a total of MAX_PATH characters.
/// 
priv enum WinPrefix {
  /// Syntax: `\`
  ///
  /// Example: `\Users\username\Documents\`
  Root
  /// Syntax: `\\?\`
  ///
  /// Example: `\\?\C:\`
  VerbatimRoot
  /// Syntax: `\\.`
  ///
  /// Example: `\\.\COM56`
  DeviceRoot
  /// Syntax: `\\<SERVER>\<SHARE>\`
  ///
  /// Example: `\\server\share\`
  UNC(hostname~ : String, shared_folder~ : String)
  /// Syntax: `<L>:\`
  ///
  /// Example: `C:\`
  ///
  /// Warning: this letter is case-insensitive.
  VolumeLetterRoot(Char)
  /// Syntax: `<L>:<rest_of_path>`
  ///
  /// Example: `C:main.mbt`
  ///
  /// 
  /// Warning: this letter is case-insensitive.
  VolumeLetter(Char)
  None
} derive(ToJson, Hash, Eq)

/// In order to make code more clean,
/// so we have to define many string constants to avoid escape sequences.

///|
const VerbatimPrefix : String =
  #|\\?\

///|
const ColonBackslash : String =
  #|:\

///|
const DevicePrefix : String =
  #|\\.\

///|
const UncPrefix : String =
  #|\\

///|
const BackSlash : Char = '\\'

///|
impl Show for WinPrefix with fn output(self, logger) {
  match self {
    Root => logger.write_char(BackSlash)
    VerbatimRoot => logger.write_string(VerbatimPrefix)
    DeviceRoot => logger.write_string(DevicePrefix)
    UNC(hostname~, shared_folder~) => {
      logger.write_string(UncPrefix)
      logger.write_string(hostname)
      logger.write_char(BackSlash)
      logger.write_string(shared_folder)
      logger.write_char(BackSlash)
    }
    VolumeLetterRoot(letter) => {
      logger.write_char(letter)
      logger.write_string(ColonBackslash)
    }
    VolumeLetter(letter) => {
      logger.write_char(letter)
      logger.write_string(":")
    }
    None => ()
  }
}

///|
fn WinPath::output(self : WinPath, logger : &Logger) -> Unit {
  let { prefix, trailing_separator, components } = self
  let mut prefix_ends_with_sep = false
  match prefix {
    Root => {
      logger.write_char(BackSlash)
      prefix_ends_with_sep = true
    }
    VerbatimRoot => {
      logger.write_string(VerbatimPrefix)
      prefix_ends_with_sep = true
    }
    DeviceRoot => {
      logger.write_string(DevicePrefix)
      prefix_ends_with_sep = true
    }
    UNC(hostname~, shared_folder~) => {
      logger.write_string(UncPrefix)
      logger.write_string(hostname)
      logger.write_char(BackSlash)
      logger.write_string(shared_folder)
      logger.write_char(BackSlash)
      prefix_ends_with_sep = true
    }
    VolumeLetterRoot(letter) => {
      logger.write_char(letter)
      logger.write_string(ColonBackslash)
      prefix_ends_with_sep = true
    }
    VolumeLetter(letter) => {
      logger.write_char(letter)
      logger.write_string(":")
    }
    None => ()
  }
  match components {
    [] =>
      match prefix {
        None | VolumeLetter(_) =>
          if trailing_separator {
            logger.write_string(".\\")
          } else {
            logger.write_char('.')
          }
        VerbatimRoot | DeviceRoot => ()
        _ => ()
      }
    [x, .. xs] => {
      if !prefix_ends_with_sep &&
        !(prefix is None) &&
        !(prefix is VolumeLetter(_)) {
        logger.write_char(BackSlash)
      }
      logger.write_view(x)
      for component in xs {
        logger.write_char(BackSlash)
        logger.write_view(component)
      }
      if trailing_separator {
        logger.write_char(BackSlash)
      }
    }
  }
}

///|
impl Show for WinPath with fn output(self, logger) {
  WinPath::output(self, logger)
}

///|
fn is_win_sep_at_view(path : StringView, index : Int) -> Bool {
  match path.get_char(index) {
    Some(ch) => is_win_sep(ch)
    _ => false
  }
}

///|
fn has_win_drive_view(path : StringView, start : Int) -> Bool {
  if start + 1 >= path.length() || path.get_char(start + 1) != Some(':') {
    false
  } else {
    match path.get_char(start) {
      Some(ch) => is_ascii_alpha(ch)
      _ => false
    }
  }
}

///|
fn skip_win_separators_view(path : StringView, start : Int) -> Int {
  let mut index = start
  while index < path.length() && is_win_sep_at_view(path, index) {
    index += 1
  }
  index
}

///|
fn find_next_win_sep_view(path : StringView, start : Int) -> Int? {
  for i = start; i < path.length(); i = i + 1 {
    if is_win_sep_at_view(path, i) {
      return Some(i)
    }
  }
  None
}

///|
fn push_windows_component(
  components : Array[StringView],
  component : StringView,
  allow_above_root~ : Bool,
) -> Unit {
  match component {
    "." => ()
    ".." =>
      match components.pop() {
        Some("..") => {
          components.push("..")
          if allow_above_root {
            components.push("..")
          }
        }
        None => if allow_above_root { components.push("..") }
        Some(_) => ()
      }
    _ => components.push(component)
  }
}

///|
fn parse_windows_components(
  path : StringView,
  start : Int,
  allow_above_root~ : Bool,
) -> Array[StringView] {
  let components : Array[StringView] = []
  let mut component_start = start
  let mut index = start
  while index <= path.length() {
    if index == path.length() || is_win_sep_at_view(path, index) {
      if component_start < index {
        push_windows_component(
          components,
          path[component_start:index],
          allow_above_root~,
        )
      }
      if index == path.length() {
        break
      }
      index = skip_win_separators_view(path, index)
      component_start = index
    } else {
      index += 1
    }
  }
  components
}

///|
fn parse_verbatim_prefixed_path(
  path : StringView,
  trailing_separator : Bool,
) -> WinPath? {
  guard path.length() >= 4 && path.get_char(2) == Some('?') else { return None }
  guard is_win_sep_at_view(path, 3) else { return None }
  let marker_end = 4
  let components = parse_windows_components(
    path,
    marker_end,
    allow_above_root=false,
  )
  Some({ prefix: VerbatimRoot, trailing_separator, components })
}

///|
fn parse_device_prefixed_path(
  path : StringView,
  trailing_separator : Bool,
) -> WinPath? {
  guard path.length() >= 4 && path.get_char(2) == Some('.') else { return None }
  guard is_win_sep_at_view(path, 3) else { return None }
  let part_start = 4
  let components = parse_windows_components(
    path,
    part_start,
    allow_above_root=false,
  )
  Some({ prefix: DeviceRoot, trailing_separator, components })
}

///|
fn parse_unc_path(path : StringView, trailing_separator : Bool) -> WinPath? {
  guard path.length() <= 2 || !is_win_sep_at_view(path, 2) else { return None }
  let hostname_start = 2
  guard hostname_start < path.length() else { return None }
  match find_next_win_sep_view(path, hostname_start) {
    Some(hostname_end) => {
      let share_start = skip_win_separators_view(path, hostname_end)
      guard share_start < path.length() else { return None }
      let share_end = match find_next_win_sep_view(path, share_start) {
        Some(index) => index
        _ => path.length()
      }
      let component_start = if share_end < path.length() {
        skip_win_separators_view(path, share_end)
      } else {
        path.length()
      }
      let components = parse_windows_components(
        path,
        component_start,
        allow_above_root=false,
      )
      Some({
        prefix: UNC(
          hostname=path[hostname_start:hostname_end].to_owned(),
          shared_folder=path[share_start:share_end].to_owned(),
        ),
        trailing_separator,
        components,
      })
    }
    _ => None
  }
}

///|
fn WinPath::parse(path : StringView) -> WinPath {
  let trailing_separator = path.length() > 0 &&
    is_win_sep_at_view(path, path.length() - 1)
  if path.length() >= 2 &&
    is_win_sep_at_view(path, 0) &&
    is_win_sep_at_view(path, 1) {
    match parse_verbatim_prefixed_path(path, trailing_separator) {
      Some(parsed) => return parsed
      _ => ()
    }
    match parse_device_prefixed_path(path, trailing_separator) {
      Some(parsed) => return parsed
      _ => ()
    }
    match parse_unc_path(path, trailing_separator) {
      Some(parsed) => return parsed
      _ => ()
    }
  }
  if has_win_drive_view(path, 0) {
    let letter = path[0:1].get_char(0).unwrap()
    if path.length() > 2 && is_win_sep_at_view(path, 2) {
      let components = parse_windows_components(
        path,
        skip_win_separators_view(path, 2),
        allow_above_root=false,
      )
      return {
        prefix: VolumeLetterRoot(letter),
        trailing_separator,
        components,
      }
    }
    let components = parse_windows_components(path, 2, allow_above_root=true)
    return { prefix: VolumeLetter(letter), trailing_separator, components }
  }
  if path.length() > 0 && is_win_sep_at_view(path, 0) {
    let components = parse_windows_components(
      path,
      skip_win_separators_view(path, 0),
      allow_above_root=false,
    )
    return { prefix: Root, trailing_separator, components }
  }
  let components = parse_windows_components(path, 0, allow_above_root=true)
  { prefix: None, trailing_separator, components }
}

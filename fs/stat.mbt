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
/// The kind of a filesystem object.
#derive(Eq, Debug)
#non_exhaustive
pub(all) enum FileKind {
  Unknown
  Regular
  Directory
  SymLink
  Socket
  Pipe
  BlockDevice
  CharDevice
  Console
}

///|
/// A filesystem timestamp, measured from the Unix epoch.
#derive(Eq, Debug)
struct Timestamp {
  sec : Int64
  nsec : Int32
}

///|
/// Returns the whole seconds since the Unix epoch.
pub fn Timestamp::sec(self : Timestamp) -> Int64 {
  self.sec
}

///|
/// Returns the nanosecond fraction within the second (0..<1_000_000_000).
pub fn Timestamp::nsec(self : Timestamp) -> Int32 {
  self.nsec
}

///|
/// Comparable identity on the same host. A filesystem may reuse it after deletion.
#derive(Eq)
struct FileIdentity {
  volume : Int64
  index : Int64
}

///|
// Native and Wasm stat jobs use these request bits and return the same bits
// for the properties they could retrieve. Identity requires both device and file ID.
const STAT_KIND : UInt32 = 1

///|
const STAT_SIZE : UInt32 = 2

///|
const REGULAR_FILE : Int64 = 1

///|
const STAT_IDENTITY : UInt32 = 0x0c

///|
const STAT_ATIME : UInt32 = 0x10

///|
const STAT_MTIME : UInt32 = 0x20

///|
const STAT_CTIME : UInt32 = 0x40

///|
// EINTR is 4 on both Linux and macOS; Windows error 4 is not EINTR.
#cfg(any(target="native", target="wasm"))
const UNIX_EINTR : Int32 = 4

///|
fn stat_property(
  path : StringView,
  request : UInt32,
  follow_symlink : Bool,
) -> FixedArray[Int64]? raise IOError {
  guard !path.contains("\u0000") else { raise IOError("stat: NUL in path") }
  query_stat_property(request, fields => {
    stat_by_path(path, request, follow_symlink, fields)
  })
}

///|
fn File::stat_property(
  self : File,
  request : UInt32,
) -> FixedArray[Int64]? raise {
  let handle = self.get_handle()
  query_stat_property(request, fields => handle.stat(request, fields))
}

///|
#locals(query)
fn query_stat_property(
  request : UInt32,
  query : (FixedArray[Int64]) -> UInt32 raise?,
) -> FixedArray[Int64]? raise? {
  // One header word, then one word for kind or two for each other query.
  let fields = FixedArray::make(if request == STAT_KIND { 2 } else { 3 }, 0L)
  let mask = query(fields)
  if (mask & request) == request {
    Some(fields)
  } else {
    None
  }
}

///|
/// Returns the file kind. Pass `follow_symlink=false` to inspect the link itself.
/// On Windows, Native and Wasm may report other reparse points as `SymLink`.
///
/// ```mbt check
/// test {
///   debug_inspect(@fs.kind("."), content="Directory")
/// }
/// ```
pub fn kind(
  path : StringView,
  follow_symlink~ : Bool = true,
) -> FileKind raise IOError {
  guard stat_property(path, STAT_KIND, follow_symlink) is Some(fields) else {
    raise IOError("kind: unavailable for \{path}")
  }
  FileKind::from_stat(fields[1])
}

///|
/// Returns the kind of the open file.
pub fn File::kind(self : File) -> FileKind raise {
  guard self.stat_property(STAT_KIND) is Some(fields) else {
    raise Failure::Failure("kind: unavailable for open file")
  }
  FileKind::from_stat(fields[1])
}

///|
fn FileKind::from_stat(value : Int64) -> FileKind {
  match value {
    1 => Regular
    2 => Directory
    3 => SymLink
    4 => Socket
    5 => Pipe
    6 => BlockDevice
    7 => CharDevice
    8 => Console
    _ => Unknown
  }
}

///|
/// Returns a regular file's size in bytes, following symbolic links.
/// Raises `IOError` for other file kinds or when the size is unavailable.
pub fn file_size(path : StringView) -> Int64 raise IOError {
  guard stat_property(path, STAT_KIND | STAT_SIZE, true) is Some(fields) &&
    fields[1] == REGULAR_FILE else {
    raise IOError("file_size: unavailable for \{path}")
  }
  fields[2]
}

///|
fn stat_time(
  path : StringView,
  request : UInt32,
  follow_symlink : Bool,
) -> Timestamp raise IOError {
  guard stat_property(path, request, follow_symlink) is Some(fields) else {
    raise IOError("stat: timestamp unavailable for \{path}")
  }
  { sec: fields[1], nsec: fields[2].to_int(), }
}

///|
fn File::stat_time(self : File, request : UInt32) -> Timestamp raise {
  guard self.stat_property(request) is Some(fields) else {
    raise Failure::Failure("stat: timestamp unavailable for open file")
  }
  { sec: fields[1], nsec: fields[2].to_int(), }
}

///|
/// Returns the last access time, following the final symbolic link by default.
pub fn atime(
  path : StringView,
  follow_symlink~ : Bool = true,
) -> Timestamp raise IOError {
  stat_time(path, STAT_ATIME, follow_symlink)
}

///|
/// Returns the last access time of the open file.
pub fn File::atime(self : File) -> Timestamp raise {
  self.stat_time(STAT_ATIME)
}

///|
/// Returns the last data modification time, following the final symbolic link by default.
pub fn mtime(
  path : StringView,
  follow_symlink~ : Bool = true,
) -> Timestamp raise IOError {
  stat_time(path, STAT_MTIME, follow_symlink)
}

///|
/// Returns the last data modification time of the open file.
///
/// ```mbt nocheck
/// fn read_with_mtime(path : String) -> (@fs.Timestamp, Bytes) raise {
///   let file = @fs.open(path, mode=ReadOnly)
///   defer file.close()
///   (file.mtime(), file.read_all())
/// }
/// ```
pub fn File::mtime(self : File) -> Timestamp raise {
  self.stat_time(STAT_MTIME)
}

///|
/// Returns the last status change time, following the final symbolic link by default.
pub fn ctime(
  path : StringView,
  follow_symlink~ : Bool = true,
) -> Timestamp raise IOError {
  stat_time(path, STAT_CTIME, follow_symlink)
}

///|
/// Returns the last status change time of the open file.
pub fn File::ctime(self : File) -> Timestamp raise {
  self.stat_time(STAT_CTIME)
}

///|
/// Returns a comparable identity if available, following the final symbolic link by default.
/// A failed path lookup raises `IOError`. On Windows, comparison is supported only
/// on NTFS. Other Windows filesystems, including ReFS, may return a non-unique ID.
pub fn identity(
  path : StringView,
  follow_symlink~ : Bool = true,
) -> FileIdentity? raise IOError {
  guard stat_property(path, STAT_IDENTITY, follow_symlink) is Some(fields) else {
    return None
  }
  FileIdentity::from_stat(fields[1], fields[2], windows=is_windows())
}

///|
/// Returns the open file's identity if available. On Windows, comparison is
/// supported only on NTFS, as with the path-based `identity` query.
pub fn File::identity(self : File) -> FileIdentity? raise {
  guard self.stat_property(STAT_IDENTITY) is Some(fields) else { return None }
  FileIdentity::from_stat(fields[1], fields[2], windows=is_windows())
}

///|
fn FileIdentity::from_stat(
  volume : Int64,
  index : Int64,
  windows~ : Bool,
) -> FileIdentity? {
  // libuv uses 0 for an unknown volume. Windows reserves zero and all-ones file IDs.
  if windows && (volume == 0 || index == 0 || index == -1) {
    None
  } else {
    Some({ volume, index, })
  }
}

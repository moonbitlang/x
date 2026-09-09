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
#borrow(path, output)
extern "c" fn native_mtime(
  path : Bytes,
  follow_symlink : Int,
  output : FixedArray[Int64],
) -> Int = "moonbit_community_unix_mtime"

///|
#borrow(path, status)
extern "c" fn native_file_size(path : Bytes, status : FixedArray[Int]) -> Int64 = "moonbit_community_unix_file_size"

///|
#borrow(path)
extern "c" fn native_mkdir(
  path : Bytes,
  permission : Int,
  recursive : Int,
) -> Int = "moonbit_community_unix_mkdir"

///|
#borrow(path, status)
extern "c" fn native_readdir(
  path : Bytes,
  include_hidden : Int,
  include_special : Int,
  status : FixedArray[Int],
) -> Bytes = "moonbit_community_unix_readdir"

///|
#borrow(path, status)
extern "c" fn native_kind(
  path : Bytes,
  follow_symlink : Int,
  status : FixedArray[Int],
) -> Int = "moonbit_community_unix_kind"

///|
#borrow(path, status)
extern "c" fn native_readlink(path : Bytes, status : FixedArray[Int]) -> Bytes = "moonbit_community_unix_readlink"

///|
#borrow(path, status)
extern "c" fn native_realpath(path : Bytes, status : FixedArray[Int]) -> Bytes = "moonbit_community_unix_realpath"

///|
#borrow(path)
extern "c" fn native_remove_all(path : Bytes) -> Int = "moonbit_community_unix_remove_all"

///|
#borrow(path)
extern "c" fn native_remove(path : Bytes) -> Int = "moonbit_community_unix_remove"

///|
#borrow(path)
extern "c" fn native_rmdir(path : Bytes, recursive : Int) -> Int = "moonbit_community_unix_rmdir"

///|
#borrow(src, dst)
extern "c" fn native_hardlink(src : Bytes, dst : Bytes) -> Int = "moonbit_community_unix_hardlink"

///|
#borrow(path, status)
extern "c" fn native_read_file(
  path : Bytes,
  sync_timestamp : Int,
  status : FixedArray[Int],
) -> Bytes = "moonbit_community_unix_read_file"

///|
#borrow(path, content)
extern "c" fn native_write_file(
  path : Bytes,
  content : Bytes,
  len : Int,
  create_mode : Int,
  permission : Int,
  sync : Int,
  append : Int,
) -> Int = "moonbit_community_unix_write_file"

///|
#borrow(path, status)
extern "c" fn native_access(
  path : Bytes,
  mode : Int,
  status : FixedArray[Int],
) -> Int = "moonbit_community_unix_access"

///|
#borrow(path)
extern "c" fn native_touch(path : Bytes) -> Int = "moonbit_community_unix_touch"

///|
#borrow(path)
extern "c" fn native_set_executable(path : Bytes) -> Int = "moonbit_community_unix_set_executable"

///|
fn cstr(s : StringView) -> Bytes raise @os_error.OSError {
  @ffi.validate_string(s, "filesystem path")
  @encoding/utf8.encode(s)
}

///|
fn fail(
  operation : String,
  detail : StringView,
  code : Int,
) -> Unit raise @os_error.OSError {
  raise OSError(code, context=operation + ": " + detail.to_owned())
}

///|
pub fn realpath(path : StringView) -> String raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let resolved = @encoding/utf8.decode_lossy(
    native_realpath(cstr(path), status)[:],
  )
  if status[0] != 0 {
    fail("realpath", path, status[0])
  }
  resolved
}

///|
/// Remove a file or symbolic link. Directories and missing paths raise an error.
pub fn remove(path : StringView) -> Unit raise @os_error.OSError {
  let code = native_remove(cstr(path))
  if code != 0 {
    fail("remove", path, code)
  }
}

///|
/// Remove a directory. With recursive=true, remove its contents first without
/// traversing symbolic links. Missing paths and non-directories raise errors.
pub fn rmdir(
  path : StringView,
  recursive? : Bool = false,
) -> Unit raise @os_error.OSError {
  let code = native_rmdir(cstr(path), if recursive { 1 } else { 0 })
  if code != 0 {
    fail("rmdir", path, code)
  }
}

///|
/// Synchronous extension: recursively remove any path; missing paths are ignored.
pub fn remove_all(path : StringView) -> Unit raise @os_error.OSError {
  let code = native_remove_all(cstr(path))
  if code != 0 {
    fail("remove_all", path, code)
  }
}

///|
/// Synchronous extension: create a hard link. An existing destination raises
/// OSError with is_EEXIST(); neither source nor destination is removed on failure.
pub fn hardlink(
  src : StringView,
  dst : StringView,
) -> Unit raise @os_error.OSError {
  let code = native_hardlink(cstr(src), cstr(dst))
  if code != 0 {
    fail("hardlink", "\{src} -> \{dst}", code)
  }
}

///|
/// Read the entire file as bytes. sync_timestamp=true synchronizes timestamp
/// changes before returning and requires write access on Windows.
pub fn read_file(
  path : StringView,
  sync_timestamp? : Bool = false,
) -> Bytes raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let bytes = native_read_file(
    cstr(path),
    if sync_timestamp {
      1
    } else {
      0
    },
    status,
  )
  if status[0] != 0 {
    fail("read_file", path, status[0])
  }
  bytes
}

///|
/// Control creation and truncation independently of append mode.
pub(all) enum CreateMode {
  OpenExisting
  TruncateExisting
  OpenOrCreate
  CreateOrTruncate
  CreateNew
}

///|
/// Synchronize no data, data and required metadata, or all file metadata.
/// On Windows, Data and Full both use write-through I/O.
pub(all) enum SyncMode {
  NoSync
  Data
  Full
}

///|
/// Write bytes. POSIX applies umask to permission on creation; Windows ignores
/// it. append does not disable truncation: use OpenOrCreate to preserve data.
/// Synchronization errors raise even if bytes were already written.
pub fn write_file(
  path : StringView,
  content : Bytes,
  create_mode? : CreateMode = CreateOrTruncate,
  permission? : Int = 0o644,
  sync? : SyncMode = Data,
  append? : Bool = false,
) -> Unit raise @os_error.OSError {
  let create_mode = match create_mode {
    OpenExisting => 0
    TruncateExisting => 1
    OpenOrCreate => 2
    CreateOrTruncate => 3
    CreateNew => 4
  }
  let sync = match sync {
    NoSync => 0
    Data => 1
    Full => 2
  }
  let code = native_write_file(
    cstr(path),
    content,
    content.length(),
    create_mode,
    permission,
    sync,
    if append {
      1
    } else {
      0
    },
  )
  if code != 0 {
    fail("write_file", path, code)
  }
}

///|
/// Synchronous extension: update an existing file's timestamp; does not create it.
pub fn touch(path : StringView) -> Unit raise @os_error.OSError {
  let code = native_touch(cstr(path))
  if code != 0 {
    fail("touch", path, code)
  }
}

///|
fn access(
  path : StringView,
  mode : Int,
  operation : String,
) -> Bool raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let result = native_access(cstr(path), mode, status)
  if status[0] != 0 {
    fail(operation, path, status[0])
  }
  result != 0
}

///|
/// Follow symlinks and test existence. Missing paths return false; other errors
/// (including an inaccessible parent directory) are raised.
pub fn exists(path : StringView) -> Bool raise @os_error.OSError {
  access(path, 0, "exists")
}

///|
/// Test read access. Missing paths and denied access return false.
pub fn can_read(path : StringView) -> Bool raise @os_error.OSError {
  access(path, 1, "can_read")
}

///|
/// Test write access. Missing paths and denied access return false.
pub fn can_write(path : StringView) -> Bool raise @os_error.OSError {
  access(path, 2, "can_write")
}

///|
/// Test execute/traverse access independently of kind. Windows checks
/// FILE_EXECUTE access, not whether the filename has an exe extension.
pub fn can_execute(path : StringView) -> Bool raise @os_error.OSError {
  access(path, 3, "can_execute")
}

///|
/// Modification time as seconds since the Unix epoch plus nanoseconds within
/// that second (0 <= nanoseconds < 1_000_000_000). Negative seconds are valid.
pub fn mtime(
  path : StringView,
  follow_symlink? : Bool = true,
) -> (Int64, Int) raise @os_error.OSError {
  let output = FixedArray::make(2, 0L)
  let code = native_mtime(
    cstr(path),
    if follow_symlink {
      1
    } else {
      0
    },
    output,
  )
  if code != 0 {
    fail("mtime", path, code)
  }
  (output[0], output[1].to_int())
}

///|
/// Return the size of a regular file in bytes, following symlinks.
pub fn file_size(path : StringView) -> Int64 raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let value = native_file_size(cstr(path), status)
  if status[0] != 0 {
    fail("file_size", path, status[0])
  }
  value
}

///|
/// Create a directory, optionally creating missing parents. An existing final
/// directory raises even with recursive=true, matching async 0.21.2.
/// POSIX applies umask to permission; Windows ignores it.
pub fn mkdir(
  path : StringView,
  permission? : Int = 0o755,
  recursive? : Bool = false,
) -> Unit raise @os_error.OSError {
  let code = native_mkdir(cstr(path), permission, if recursive { 1 } else { 0 })
  if code != 0 {
    fail("mkdir", path, code)
  }
}

///|
/// Synchronous extension: add all POSIX execute bits; a no-op on Windows.
pub fn set_executable(path : StringView) -> Unit raise @os_error.OSError {
  let code = native_set_executable(cstr(path))
  if code != 0 {
    fail("set_executable", path, code)
  }
}

///|
pub(all) enum FileKind {
  Unknown
  Regular
  Directory
  SymLink
  Socket
  Pipe
  BlockDevice
  CharDevice
} derive(Eq)

///|
pub extend FileKind with Eq::{not_equal, equal}

///|
/// Missing paths raise; Unknown is an existing object of an unrecognized kind.
pub fn kind(
  path : StringView,
  follow_symlink? : Bool = true,
) -> FileKind raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let value = native_kind(
    cstr(path),
    if follow_symlink {
      1
    } else {
      0
    },
    status,
  )
  if status[0] != 0 {
    fail("kind", path, status[0])
  }
  match value {
    1 => Regular
    2 => Directory
    3 => SymLink
    4 => Socket
    5 => Pipe
    6 => BlockDevice
    7 => CharDevice
    _ => Unknown
  }
}

///|
/// Read the stored symbolic-link target without resolving it. Relative and
/// dangling targets are preserved. Windows also supports directory junctions.
/// Absolute Windows targets retain the Win32 extended path prefix (`\\?\`).
pub fn readlink(path : StringView) -> String raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let target = @encoding/utf8.decode_lossy(
    native_readlink(cstr(path), status)[:],
  )
  if status[0] != 0 {
    fail("readlink", path, status[0])
  }
  target
}

///|
fn read_dir(
  path : StringView,
  include_hidden : Bool,
  include_special : Bool,
  operation : String,
) -> Array[String] raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let raw = native_readdir(
    cstr(path),
    if include_hidden {
      1
    } else {
      0
    },
    if include_special {
      1
    } else {
      0
    },
    status,
  )
  if status[0] != 0 {
    fail(operation, path, status[0])
  }
  let entries : Array[String] = []
  let mut cursor = 0
  while cursor < raw.length() {
    let name_start = cursor
    let mut name_end = name_start
    while name_end < raw.length() && raw[name_end] != b'\x00' {
      name_end += 1
    }
    if name_end == raw.length() {
      @ffi.invalid_data("\{operation}: malformed directory entry for \{path}")
    }
    let name = @encoding/utf8.decode_lossy(raw[name_start:name_end])
    entries.push(name)
    cursor = name_end + 1
  }
  entries
}

///|
/// List names. Hidden means a leading dot on POSIX and the hidden attribute on
/// Windows. Special entries are "." and "..". Sorting uses Array::sort, like
/// async (String comparison is length-first, then by code units).
pub fn readdir(
  path : StringView,
  include_hidden? : Bool = true,
  include_special? : Bool = false,
  sort? : Bool = false,
) -> Array[String] raise @os_error.OSError {
  let names = read_dir(path, include_hidden, include_special, "readdir")
  if sort {
    names.sort()
  }
  names
}

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
/// Access allowed on an opened file.
pub(all) enum Mode {
  ReadOnly = 0
  WriteOnly
  ReadWrite
}

///|
/// File creation and truncation behavior. On Node.js for Windows,
/// TruncateExisting opens the existing file and then truncates the same handle.
/// On Windows, Node.js and the Wasm host do not support TruncateExisting
/// combined with append mode.
pub(all) enum CreateMode {
  /// Fail if the file does not exist.
  OpenExisting = 0
  /// Truncate an existing file; fail if missing.
  TruncateExisting
  /// Create if missing; preserve an existing file.
  OpenOrCreate
  /// Create if missing; truncate an existing file.
  CreateOrTruncate
  /// Fail if the file already exists.
  CreateNew
}

///|
/// Durability after each write: none, data and necessary metadata, or all metadata.
/// Data may provide the stronger Full guarantee on some platforms. Neither
/// mode synchronizes the parent directory of a newly created file.
pub(all) enum SyncMode {
  NoSync = 0
  Data
  Full
}

///|
/// Request the operating system's append position instead of a file offset.
const APPEND_POSITION : Int64 = -1

///|
/// A synchronous file with independent read and write positions, initially zero.
/// Aliases share positions and closure state. Close explicitly (usually in defer).
/// Intended for seekable files; concurrent access to this object is not supported.
/// JS positions must fit in an exact Number (at most 9007199254740991).
///
/// ```mbt nocheck
/// fn read_header(path : String) -> Bytes raise {
///   let file = @fs.open(path, mode=ReadOnly)
///   defer file.close()
///   file.read_exactly(16)
/// }
/// ```
struct File {
  mut handle : FileHandle?
  mode : Mode
  append : Bool
  mut read_position : Int64
  mut write_position : Int64
}

///|
/// Opens a file on Native, Wasm or Node.js. WasmGC is not supported.
/// Wasm requires the host's `moonbitlang/async` file-job ABI, including
/// `thread_pool/run_job`. JS requires Node.js with `process.getBuiltinModule`.
/// `permission` applies only when creating a file, is filtered by the Unix umask,
/// and is ignored on Windows. Paths are not normalized. Append applies only to
/// sequential writes; it does not override the selected creation mode.
/// OS failures raise OSError; invalid arguments raise Failure. On Wasm an
/// interrupted open job is reported to the caller: the host also queries
/// metadata, so blindly repeating the job could truncate an opened file twice.
pub fn open(
  path : StringView,
  mode~ : Mode,
  create_mode~ : CreateMode = OpenExisting,
  append~ : Bool = false,
  permission~ : Int32 = 0o644,
  sync~ : SyncMode = NoSync,
) -> File raise {
  guard !path.contains("\u0000") else {
    raise Failure::Failure("open: NUL in path")
  }
  guard !(mode is ReadOnly &&
    (append || create_mode is (TruncateExisting | CreateOrTruncate))) else {
    raise Failure::Failure("open: append and truncation require write access")
  }
  let handle = open_file_handle(
    path.to_owned(),
    mode,
    create_mode,
    append,
    permission,
    sync,
  )
  { handle: Some(handle), mode, append, read_position: 0, write_position: 0, }
}

///|
/// Creates a writable file, truncating an existing file unless `allow_existing=false`.
pub fn create(
  path : StringView,
  allow_existing~ : Bool = true,
  permission~ : Int32 = 0o644,
  sync~ : SyncMode = NoSync,
) -> File raise {
  open(
    path,
    mode=WriteOnly,
    create_mode=if allow_existing { CreateOrTruncate } else { CreateNew },
    permission~,
    sync~,
  )
}

///|
fn File::get_handle(self : File) -> FileHandle raise {
  guard self.handle is Some(handle) else {
    raise Failure::Failure("file is closed")
  }
  handle
}

///|
fn File::check_access(self : File, write~ : Bool) -> FileHandle raise {
  let handle = self.get_handle()
  guard !(if write { self.mode is ReadOnly } else { self.mode is WriteOnly }) else {
    raise Failure::Failure(
      if write {
        "file is not writable"
      } else {
        "file is not readable"
      },
    )
  }
  handle
}

///|
fn check_range(capacity : Int32, offset : Int32, len : Int32) -> Unit raise {
  guard offset >= 0 &&
    offset <= capacity &&
    len >= 0 &&
    len <= capacity - offset else {
    raise Failure::Failure("invalid buffer range")
  }
}

///|
fn check_position(position : Int64, len : Int32) -> Unit raise {
  guard position >= 0 && position <= max_file_position - len.to_int64() else {
    raise Failure::Failure("file position out of range")
  }
}

///|
/// Reads at most `max_len` bytes, returning the count (zero means EOF for a
/// nonempty request). Short reads are allowed. Advances only the read position.
pub fn File::read(
  self : File,
  buffer : FixedArray[Byte],
  offset~ : Int32 = 0,
  max_len~ : Int32 = buffer.length() - offset,
) -> Int32 raise {
  let handle = self.check_access(write=false)
  check_range(buffer.length(), offset, max_len)
  check_position(self.read_position, max_len)
  if max_len == 0 {
    return 0
  }
  let n = handle.read_once(buffer, offset, max_len, self.read_position)
  self.read_position += n.to_int64()
  n
}

///|
/// Fills the requested range or stops at EOF. Does not change either cursor.
pub fn File::read_at(
  self : File,
  buffer : FixedArray[Byte],
  position~ : Int64,
  offset~ : Int32 = 0,
  len~ : Int32 = buffer.length() - offset,
) -> Int32 raise {
  let handle = self.check_access(write=false)
  check_range(buffer.length(), offset, len)
  check_position(position, len)
  for total = 0; total < len; {
    let n = handle.read_once(
      buffer,
      offset + total,
      len - total,
      position + total.to_int64(),
    )
    if n == 0 {
      break total
    }
    continue total + n
  } nobreak {
    len
  }
}

///|
/// Reads until EOF from the current read position. File size is not assumed
/// stable. The returned bytes own their storage.
pub fn File::read_all(self : File) -> Bytes raise {
  let handle = self.check_access(write=false)
  let size = (handle.size() - self.read_position) catch { _ => 0L }
  let hint = if size > 0 && size < MAX_FILE_BYTES.to_int64() {
    Some(size.to_int())
  } else {
    None
  }
  read_all_with_hint((buffer, offset) => self.read(buffer, offset~), hint)
}

///|
/// Reads exactly `len` bytes or raises ReaderClosed on premature EOF. Bytes already
/// read advance the read position even when a later read fails.
pub fn File::read_exactly(self : File, len : Int32) -> Bytes raise {
  let handle = self.check_access(write=false)
  guard len >= 0 else { raise Failure::Failure("negative read length") }
  check_position(self.read_position, len)
  let buffer : FixedArray[Byte] = FixedArray::make(len, 0)
  for total = 0; total < len; {
    let n = handle.read_once(buffer, total, len - total, self.read_position)
    guard n > 0 else { raise ReaderClosed }
    self.read_position += n.to_int64()
    continue total + n
  }
  buffer.unsafe_reinterpret_as_bytes()
}

///|
/// Performs one write. Short writes are allowed; advances only the write position.
pub fn File::write_once(
  self : File,
  buffer : Bytes,
  offset~ : Int32,
  len~ : Int32,
) -> Int32 raise {
  let handle = self.check_access(write=true)
  check_range(buffer.length(), offset, len)
  check_position(self.write_position, len)
  if len == 0 {
    return 0
  }
  let n = handle.write(
    buffer,
    offset,
    len,
    if self.append {
      APPEND_POSITION
    } else {
      self.write_position
    },
  )
  self.write_position += n.to_int64()
  handle.finish_write()
  n
}

///|
/// Writes all bytes, advancing only the write position. Append writes use the
/// operating system's append mode. A multi-call write is not atomic; errors may
/// leave a written prefix and do not roll back the file or cursor.
pub fn File::write(self : File, data : BytesView) -> Unit raise {
  let handle = self.check_access(write=true)
  check_position(self.write_position, data.length())
  for total = 0; total < data.length(); {
    let n = handle.write(
      data.data(),
      data.start_offset() + total,
      data.length() - total,
      if self.append {
        APPEND_POSITION
      } else {
        self.write_position
      },
    )
    guard n > 0 else { raise Failure::Failure("write made no progress") }
    self.write_position += n.to_int64()
    handle.finish_write()
    continue total + n
  }
}

///|
/// Writes all bytes at `position`, preserving both cursors. Forbidden in append
/// mode. An error can leave a written prefix.
pub fn File::write_at(
  self : File,
  data : BytesView,
  position~ : Int64,
) -> Unit raise {
  let handle = self.check_access(write=true)
  guard !self.append else {
    raise Failure::Failure("write_at is unavailable in append mode")
  }
  check_position(position, data.length())
  for total = 0; total < data.length(); {
    let n = handle.write(
      data.data(),
      data.start_offset() + total,
      data.length() - total,
      position + total.to_int64(),
    )
    guard n > 0 else { raise Failure::Failure("write made no progress") }
    handle.finish_write()
    continue total + n
  }
}

///|
/// Queries the current size without moving either cursor.
pub fn File::size(self : File) -> Int64 raise {
  self.get_handle().size()
}

///|
/// Synchronizes data and metadata, or only data and necessary metadata when
/// `only_data=true`. Does not synchronize the parent directory.
pub fn File::sync(self : File, only_data~ : Bool = false) -> Unit raise {
  self.get_handle().sync(only_data)
}

///|
fn File::close_result(self : File) -> Error? {
  guard self.handle is Some(handle) else { return None }
  self.handle = None
  handle.close()
}

///|
/// Closes once, invalidating all aliases. Repeated calls do nothing. Close errors
/// are ignored so this method can be used in defer; use sync to check durability.
pub fn File::close(self : File) -> Unit {
  ignore(self.close_result())
}

///|
/// Reads the whole file. Optionally synchronizes its access timestamp.
/// A close error is reported if reading and synchronization succeeded.
pub fn read_file(
  path : StringView,
  sync_timestamp~ : Bool = false,
) -> Bytes raise {
  let file = open(path, mode=ReadOnly)
  defer file.close()
  let result = file.read_all()
  if sync_timestamp {
    file.sync()
  }
  if file.close_result() is Some(error) {
    raise error
  }
  result
}

///|
/// Writes the whole byte view. Without an explicit creation mode, append opens
/// or creates without truncation; other writes create or truncate. An explicit
/// creation mode is always honored, including truncation combined with append.
/// Defaults to permission 0644 and Data synchronization.
/// Does not create parents or replace the file atomically.
/// A close error is reported if writing succeeded.
///
/// ```mbt check
/// test {
///   let path = "tmp_fs_write_file_example"
///   @fs.write_file(path, b"old", sync=NoSync)
///   defer @fs.remove_file(path)
///   @fs.write_file(path, b"new", append=true, sync=NoSync)
///   assert_eq(@fs.read_file(path), b"oldnew")
/// }
/// ```
pub fn write_file(
  path : StringView,
  data : BytesView,
  create_mode? : CreateMode,
  permission~ : Int32 = 0o644,
  sync~ : SyncMode = Data,
  append~ : Bool = false,
) -> Unit raise {
  let file = open(
    path,
    mode=WriteOnly,
    create_mode=create_mode.unwrap_or(
      if append {
        OpenOrCreate
      } else {
        CreateOrTruncate
      },
    ),
    permission~,
    sync~,
    append~,
  )
  defer file.close()
  file.write(data)
  // Opening may create or truncate the file even when no bytes are written.
  if data.is_empty() && sync is (Data | Full) {
    file.sync(only_data=sync is Data)
  }
  if file.close_result() is Some(error) {
    raise error
  }
}

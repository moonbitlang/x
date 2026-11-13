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
// Node's writeSync accepts a Number position; reject lossy Int64 conversions.
let max_file_position : Int64 = 9007199254740991

///|
priv struct FileHandle {
  fd : Int32
  sync : SyncMode
}

///|
/// An internal Node.js OS failure with its signed libuv error code and context.
/// Available only on JS. Native and Wasm use core/async/os_error.OsError.
/// core's OsError does not currently support JS.
/// The legacy whole-file APIs continue to raise IOError.
priv suberror OSError {
  OSError(Int32, context~ : String)
}

///|
impl Show for OSError with fn output(self, logger) {
  let OSError(code, context~) = self
  let message = "\{context}: \{os_error_message(code)}"
  logger <+ "OSError(\{Repr(message)})"
}

///|
impl Debug for OSError with fn to_repr(self) {
  let OSError(code, context~) = self
  Repr::opaque_(
    "@fs.OSError",
    Repr::string("\{context}: \{os_error_message(code)}"),
  )
}

///|
#external
priv type FileJsResult

///|
extern "js" fn FileJsResult::is_ok(self : FileJsResult) -> Bool =
  #| result => result.ok

///|
extern "js" fn FileJsResult::message(self : FileJsResult) -> String =
  #| result => result.error

///|
extern "js" fn FileJsResult::int_value(self : FileJsResult) -> Int32 =
  #| result => result.value

///|
extern "js" fn FileJsResult::size(self : FileJsResult) -> Int64 =
  #| result => result.value

///|
fn FileJsResult::check(self : FileJsResult) -> Unit raise {
  guard self.is_ok() else {
    let code = self.errno()
    if code != 0 {
      raise OSError(code, context=self.context())
    }
    raise Failure::Failure(self.message())
  }
}

///|
extern "js" fn FileJsResult::errno(self : FileJsResult) -> Int32 =
  #| result => result.errno ?? 0

///|
extern "js" fn FileJsResult::context(self : FileJsResult) -> String =
  #| result => result.context

///|
#external
priv type SystemErrorMap

///|
#module("node:util")
extern "js" fn get_system_error_map() -> SystemErrorMap = "getSystemErrorMap"

///|
extern "js" fn system_error_message(
  get_map : () -> SystemErrorMap,
  error : Int32,
) -> String =
  #| function message(getMap, error) {
  #|   const map = message.map ??= getMap();
  #|   return map.get(error)?.[1] ?? `Unknown system error ${error}`;
  #| }

///|
fn os_error_message(error : Int32) -> String {
  system_error_message(get_system_error_map, error)
}

///|
#module("node:fs")
extern "js" fn open_sync(
  path : String,
  flags : Int32,
  permission : Int32,
) -> Int32 = "openSync"

///|
#module("node:fs")
extern "js" fn ftruncate_sync(fd : Int32, len : Int32) -> Unit = "ftruncateSync"

///|
#module("node:fs")
extern "js" fn close_sync(fd : Int32) -> Unit = "closeSync"

///|
// Passing a #module function binding as a value wraps it in a function, so it
// cannot expose fs.constants. Read the constants only when opening a file.
extern "js" fn node_open(
  open : (String, Int32, Int32) -> Int32,
  truncate : (Int32, Int32) -> Unit,
  close : (Int32) -> Unit,
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
) -> FileJsResult =
  #| (open, truncate, close, path, mode, createMode, append, permission) => {
  #|   let fd;
  #|   try {
  #|     if (typeof process.getBuiltinModule !== "function") {
  #|       throw Error("requires process.getBuiltinModule (Node.js 20.16+ on 20.x, or 22.3+)");
  #|     }
  #|     const c = process.getBuiltinModule("fs").constants;
  #|     const isWindows = process.platform === "win32";
  #|     // Windows TruncateExisting first opens an existing file, then truncates
  #|     // that same descriptor, as documented by CreateMode.
  #|     const truncateExisting = isWindows && createMode === 1;
  #|     let flags = [c.O_RDONLY, c.O_WRONLY, c.O_RDWR][mode];
  #|     flags |= [0, truncateExisting ? 0 : c.O_TRUNC, c.O_CREAT, c.O_CREAT | c.O_TRUNC, c.O_CREAT | c.O_EXCL][createMode];
  #|     if (append) flags |= c.O_APPEND;
  #|     // Ignore permission on Windows instead of letting Node turn a missing
  #|     // owner-write bit into FILE_ATTRIBUTE_READONLY.
  #|     fd = open(path, flags, isWindows ? 0o666 : permission);
  #|     if (truncateExisting) truncate(fd, 0);
  #|     return {ok: true, value: fd};
  #|   } catch (error) {
  #|     if (fd !== undefined) { try { close(fd); } catch {} }
  #|     return {ok: false, errno: error.errno, context: `open ${path}`, error: `open ${path}: ${error.message}`};
  #|   }
  #| }

///|
fn open_file_handle(
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileHandle raise {
  let result = node_open(
    open_sync, ftruncate_sync, close_sync, path, mode, create_mode, append, permission,
  )
  result.check()
  { fd: result.int_value(), sync, }
}

///|
// JavaScript Number for a position, or null for an append write.
#external
priv type NodePosition

///|
#module("node:fs")
extern "js" fn read_sync(
  fd : Int32,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : NodePosition,
) -> Int32 = "readSync"

///|
extern "js" fn node_read(
  read : (Int32, FixedArray[Byte], Int32, Int32, NodePosition) -> Int32,
  fd : Int32,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJsResult =
  #| (read, fd, buffer, offset, len, position) => {
  #|   try { return {ok: true, value: read(fd, buffer, offset, len, Number(position))}; }
  #|   catch (error) { return {ok: false, errno: error.errno, context: "read", error: `read: ${error.message}`}; }
  #| }

///|
fn FileHandle::read_once(
  self : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise {
  let result = node_read(read_sync, self.fd, buffer, offset, len, position)
  result.check()
  result.int_value()
}

///|
#module("node:fs")
extern "js" fn write_sync(
  fd : Int32,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : NodePosition,
) -> Int32 = "writeSync"

///|
extern "js" fn node_write(
  write : (Int32, Bytes, Int32, Int32, NodePosition) -> Int32,
  fd : Int32,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJsResult =
  #| (write, fd, buffer, offset, len, position) => {
  #|   // MoonBit may represent the negative append sentinel as unsigned bits.
  #|   try { return {ok: true, value: write(fd, buffer, offset, len, BigInt.asIntN(64, position) < 0n ? null : Number(position))}; }
  #|   catch (error) { return {ok: false, errno: error.errno, context: "write", error: `write: ${error.message}`}; }
  #| }

///|
fn FileHandle::write(
  self : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> Int32 raise {
  let result = node_write(write_sync, self.fd, buffer, offset, len, position)
  result.check()
  result.int_value()
}

///|
#module("node:fs")
extern "js" fn fstat_sync(fd : Int32, options : FsOptions) -> FsStats = "fstatSync"

///|
extern "js" fn node_size(
  stat : (Int32, FsOptions) -> FsStats,
  fd : Int32,
) -> FileJsResult =
  #| (stat, fd) => {
  #|   try {
  #|     const info = stat(fd, {bigint: true});
  #|     if (!info.isFile()) return {ok: false, error: "size: not a regular file"};
  #|     if (info.size > 9223372036854775807n) return {ok: false, error: "size: exceeds Int64"};
  #|     return {ok: true, value: info.size};
  #|   } catch (error) { return {ok: false, errno: error.errno, context: "size", error: `size: ${error.message}`}; }
  #| }

///|
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  let result = node_size(fstat_sync, self.fd)
  result.check()
  result.size()
}

///|
#module("node:fs")
extern "js" fn fdatasync_sync(fd : Int32) -> Unit = "fdatasyncSync"

///|
#module("node:fs")
extern "js" fn fsync_sync(fd : Int32) -> Unit = "fsyncSync"

///|
extern "js" fn node_sync(sync : (Int32) -> Unit, fd : Int32) -> FileJsResult =
  #| (sync, fd) => {
  #|   try { sync(fd); return {ok: true}; }
  #|   catch (error) { return {ok: false, errno: error.errno, context: "sync", error: `sync: ${error.message}`}; }
  #| }

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise {
  node_sync(if only_data { fdatasync_sync } else { fsync_sync }, self.fd).check()
}

///|
fn FileHandle::finish_write(self : FileHandle) -> Unit raise {
  match self.sync {
    NoSync => ()
    Data => self.sync(true)
    Full => self.sync(false)
  }
}

///|
extern "js" fn node_close(close : (Int32) -> Unit, fd : Int32) -> FileJsResult =
  #| (close, fd) => {
  #|   try { close(fd); return {ok: true}; }
  #|   catch (error) { return {ok: false, errno: error.errno, context: "close", error: `close: ${error.message}`}; }
  #| }

///|
fn FileHandle::close(self : FileHandle) -> Error? {
  let result = node_close(close_sync, self.fd)
  result.check() catch {
    error => return Some(error)
  }
  None
}

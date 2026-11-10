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
#external
priv type NodeFs

///|
#module("node:process")
extern "js" fn get_builtin_module(name : String) -> NodeFs = "getBuiltinModule"

///|
#external
priv type FileHandle

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
extern "js" fn FileJsResult::number(self : FileJsResult) -> Int64 =
  #| result => result.value

///|
extern "js" fn FileJsResult::handle(self : FileJsResult) -> FileHandle =
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
extern "js" fn os_error_message(error : Int32) -> String =
  #| error => process.getBuiltinModule("util").getSystemErrorMap().get(error)?.[1] ?? `Unknown system error ${error}`

///|
extern "js" fn node_open(
  fs : NodeFs,
  path : String,
  mode : Mode,
  create_mode : CreateMode,
  append : Bool,
  permission : Int32,
  sync : SyncMode,
) -> FileJsResult =
  #| (fs, path, mode, createMode, append, permission, sync) => {
  #|   let fd;
  #|   try {
  #|     const c = fs.constants;
  #|     // Node/libuv rejects O_TRUNC without O_CREAT on Windows.
  #|     const truncateExisting = process.platform === "win32" && createMode === 1;
  #|     let flags = [c.O_RDONLY, c.O_WRONLY, c.O_RDWR][mode];
  #|     flags |= [0, truncateExisting ? 0 : c.O_TRUNC, c.O_CREAT, c.O_CREAT | c.O_TRUNC, c.O_CREAT | c.O_EXCL][createMode];
  #|     if (append) flags |= c.O_APPEND;
  #|     fd = fs.openSync(path, flags, permission);
  #|     if (truncateExisting) fs.ftruncateSync(fd, 0);
  #|     return {ok: true, value: {fs, fd, sync}};
  #|   } catch (error) {
  #|     if (fd !== undefined) { try { fs.closeSync(fd); } catch {} }
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
    get_builtin_module("fs"),
    path,
    mode,
    create_mode,
    append,
    permission,
    sync,
  )
  result.check()
  result.handle()
}

///|
extern "js" fn node_read(
  handle : FileHandle,
  buffer : FixedArray[Byte],
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJsResult =
  #| (h, buffer, offset, len, position) => {
  #|   try { return {ok: true, value: BigInt(h.fs.readSync(h.fd, buffer, offset, len, Number(position)))}; }
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
  let result = node_read(self, buffer, offset, len, position)
  result.check()
  result.number().to_int()
}

///|
extern "js" fn node_write(
  handle : FileHandle,
  buffer : Bytes,
  offset : Int32,
  len : Int32,
  position : Int64,
) -> FileJsResult =
  #| (h, buffer, offset, len, position) => {
  #|   try { return {ok: true, value: BigInt(h.fs.writeSync(h.fd, buffer, offset, len, position < 0n ? null : Number(position)))}; }
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
  let result = node_write(self, buffer, offset, len, position)
  result.check()
  result.number().to_int()
}

///|
extern "js" fn node_size(handle : FileHandle) -> FileJsResult =
  #| h => {
  #|   try {
  #|     const stat = h.fs.fstatSync(h.fd, {bigint: true});
  #|     if (!stat.isFile()) return {ok: false, error: "size: not a regular file"};
  #|     if (stat.size > 9223372036854775807n) return {ok: false, error: "size: exceeds Int64"};
  #|     return {ok: true, value: stat.size};
  #|   } catch (error) { return {ok: false, errno: error.errno, context: "size", error: `size: ${error.message}`}; }
  #| }

///|
fn FileHandle::size(self : FileHandle) -> Int64 raise {
  let result = node_size(self)
  result.check()
  result.number()
}

///|
extern "js" fn node_sync(handle : FileHandle, only_data : Bool) -> FileJsResult =
  #| (h, onlyData) => {
  #|   try {
  #|     if (onlyData) h.fs.fdatasyncSync(h.fd); else h.fs.fsyncSync(h.fd);
  #|     return {ok: true};
  #|   } catch (error) { return {ok: false, errno: error.errno, context: "sync", error: `sync: ${error.message}`}; }
  #| }

///|
fn FileHandle::sync(self : FileHandle, only_data : Bool) -> Unit raise {
  node_sync(self, only_data).check()
}

///|
extern "js" fn FileHandle::sync_mode(self : FileHandle) -> SyncMode =
  #| h => h.sync

///|
fn FileHandle::finish_write(self : FileHandle) -> Unit raise {
  match self.sync_mode() {
    NoSync => ()
    Data => self.sync(true)
    Full => self.sync(false)
  }
}

///|
extern "js" fn node_close(handle : FileHandle) -> FileJsResult =
  #| h => {
  #|   try { h.fs.closeSync(h.fd); return {ok: true}; }
  #|   catch (error) { return {ok: false, errno: error.errno, context: "close", error: `close: ${error.message}`}; }
  #| }

///|
fn FileHandle::close(self : FileHandle) -> Error? {
  let result = node_close(self)
  result.check() catch {
    error => return Some(error)
  }
  None
}

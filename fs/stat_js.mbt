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
#module("node:fs")
extern "js" fn stat_sync_bigint(path : String, options : FsOptions) -> FsStats = "statSync"

///|
#module("node:fs")
extern "js" fn lstat_sync_bigint(path : String, options : FsOptions) -> FsStats = "lstatSync"

///|
extern "js" fn is_windows() -> Bool =
  #| () => process.platform === 'win32'

///|
extern "js" fn node_stat(
  query : (FsOptions) -> FsStats,
  request : UInt32,
  fields : FixedArray[Int64],
) -> FileJsResult =
  #| (query, request, fields) => {
  #|   try {
  #|     const s = query({ bigint: true });
  #|     if (request === 1) { // kind
  #|       if (s.isFile()) fields[1] = 1n;
  #|       else if (s.isDirectory()) fields[1] = 2n;
  #|       else if (s.isSymbolicLink()) fields[1] = 3n;
  #|       else if (s.isSocket()) fields[1] = 4n;
  #|       else if (s.isFIFO()) fields[1] = 5n;
  #|       else if (s.isBlockDevice()) fields[1] = 6n;
  #|       else if (s.isCharacterDevice()) fields[1] = 7n;
  #|     } else if (request === 3) { // regular-file size
  #|       fields[1] = s.isFile() ? 1n : 0n;
  #|       fields[2] = s.size;
  #|     } else if (request === 12) { // device and file ID
  #|       fields[1] = s.dev;
  #|       fields[2] = BigInt.asIntN(64, s.ino);
  #|     } else {
  #|       const ns = request === 16 ? s.atimeNs : request === 32 ? s.mtimeNs : s.ctimeNs;
  #|       let fraction = ns % 1000000000n;
  #|       if (fraction < 0n) fraction += 1000000000n;
  #|       fields[1] = (ns - fraction) / 1000000000n;
  #|       fields[2] = fraction;
  #|     }
  #|     return { ok: true };
  #|   } catch (error) { return { ok: false, errno: error.errno, context: error.syscall, error: error.message }; }
  #| }

///|
fn stat_by_path(
  path : StringView,
  request : UInt32,
  follow_symlink : Bool,
  fields : FixedArray[Int64],
) -> UInt32 raise IOError {
  let query = if follow_symlink { stat_sync_bigint } else { lstat_sync_bigint }
  let result = node_stat(
    options => query(path.to_owned(), options),
    request,
    fields,
  )
  guard result.is_ok() else {
    raise IOError("stat \{path}: \{result.message()}")
  }
  request
}

///|
fn FileHandle::stat(
  self : FileHandle,
  request : UInt32,
  fields : FixedArray[Int64],
) -> UInt32 raise {
  node_stat(options => fstat_sync(self.fd, options), request, fields).check()
  request
}

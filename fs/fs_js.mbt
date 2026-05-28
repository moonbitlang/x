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
#external
priv type FsStats

///|
#external
priv type FsOptions

///|
#external
priv type FsBytesResult

///|
extern "js" fn FsBytesResult::is_ok(self : Self) -> Bool =
  #| (res) => res.tag === "ok"

///|
extern "js" fn FsBytesResult::content(self : Self) -> Bytes =
  #| (res) => res.content

///|
extern "js" fn FsBytesResult::error_message(self : Self) -> String =
  #| (res) => res.content

///|
#external
priv type FsStringArrayResult

///|
extern "js" fn FsStringArrayResult::is_ok(self : Self) -> Bool =
  #| (res) => res.tag === "ok"

///|
extern "js" fn FsStringArrayResult::content(self : Self) -> Array[String] =
  #| (res) => res.content

///|
extern "js" fn FsStringArrayResult::error_message(self : Self) -> String =
  #| (res) => res.content

///|
#external
priv type FsBoolResult

///|
extern "js" fn FsBoolResult::is_ok(self : Self) -> Bool =
  #| (res) => res.tag === "ok"

///|
extern "js" fn FsBoolResult::content(self : Self) -> Bool =
  #| (res) => res.content

///|
extern "js" fn FsBoolResult::error_message(self : Self) -> String =
  #| (res) => res.content

///|
#external
priv type FsUnitResult

///|
extern "js" fn FsUnitResult::is_ok(self : Self) -> Bool =
  #| (res) => res.tag === "ok"

///|
extern "js" fn FsUnitResult::error_message(self : Self) -> String =
  #| (res) => res.content

///|
#module("fs")
extern "js" fn read_file_sync(path : String) -> Bytes = "readFileSync"

///|
extern "js" fn read_file_ffi(
  read_file : (String) -> Bytes,
  path : String,
) -> FsBytesResult =
  #| function(readFile, path) {
  #|   try {
  #|     const content = readFile(path);
  #|     return { tag: "ok", content };
  #|   } catch (error) {
  #|     return { tag: "err", content: error.message };
  #|   }
  #| }

///|
#module("fs")
extern "js" fn write_file_sync(path : String, content : Bytes) -> Unit = "writeFileSync"

///|
extern "js" fn write_file_ffi(
  write_file : (String, Bytes) -> Unit,
  path : String,
  content : Bytes,
) -> FsUnitResult =
  #| function(writeFile, path, content) {
  #|   try {
  #|     writeFile(path, Buffer.from(content));
  #|     return { tag: "ok", content: "" };
  #|   } catch (error) {
  #|     return { tag: "err", content: error.message };
  #|   }
  #| }

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let res = read_file_ffi(read_file_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
  res.content()
}

///|
fn read_file_to_string_internal(
  path : String,
  encoding? : String = "utf8",
) -> String raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  let bytes = read_file_to_bytes_internal(path)
  @ffi.utf8_bytes_to_mbt_string(bytes)
}

///|
fn write_bytes_to_file_internal(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  let res = write_file_ffi(write_file_sync, path, content)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
}

///|
fn write_string_to_file_internal(
  path : String,
  content : String,
  encoding? : String = "utf8",
) -> Unit raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  let bytes = @ffi.mbt_string_to_utf8_bytes(content, false)
  write_bytes_to_file_internal(path, bytes)
}

///|
#module("fs")
extern "js" fn path_exists_ffi(path : String) -> Bool = "existsSync"

///|
pub fn path_exists_internal(path : String) -> Bool {
  path_exists_ffi(path)
}

///|
#module("fs")
extern "js" fn read_dir_sync(path : String) -> Array[String] = "readdirSync"

///|
extern "js" fn read_dir_ffi(
  read_dir : (String) -> Array[String],
  path : String,
) -> FsStringArrayResult =
  #| function(readDir, path) {
  #|  try {
  #|    const files = readDir(path);
  #|    return { tag: "ok", content: files };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn read_dir_internal(path : String) -> Array[String] raise IOError {
  let res = read_dir_ffi(read_dir_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
  res.content()
}

///|
#module("fs")
extern "js" fn create_dir_sync(path : String, options : FsOptions) -> Unit = "mkdirSync"

///|
extern "js" fn create_dir_ffi(
  create_dir : (String, FsOptions) -> Unit,
  path : String,
) -> FsUnitResult =
  #| function(createDir, path) {
  #|  try {
  #|    createDir(path, { recursive: true });
  #|    return { tag: "ok", content: "" };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn create_dir_internal(path : String) -> Unit raise IOError {
  let res = create_dir_ffi(create_dir_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
}

///|
#module("fs")
extern "js" fn stat_sync(path : String) -> FsStats = "statSync"

///|
extern "js" fn is_dir_ffi(
  stat : (String) -> FsStats,
  path : String,
) -> FsBoolResult =
  #| function(stat, path) {
  #|  try {
  #|    const stats = stat(path);
  #|    return { tag: "ok", content: stats.isDirectory() };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  let res = is_dir_ffi(stat_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
  res.content()
}

///|
extern "js" fn is_file_ffi(
  stat : (String) -> FsStats,
  path : String,
) -> FsBoolResult =
  #| function(stat, path) {
  #|  try {
  #|    const stats = stat(path);
  #|    return { tag: "ok", content: stats.isFile() };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  let res = is_file_ffi(stat_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
  res.content()
}

///|
#module("fs")
extern "js" fn remove_dir_sync(path : String, options : FsOptions) -> Unit = "rmSync"

///|
extern "js" fn remove_dir_ffi(
  remove_dir : (String, FsOptions) -> Unit,
  path : String,
) -> FsUnitResult =
  #| function(removeDir, path) {
  #|  try {
  #|    removeDir(path, { recursive: true });
  #|    return { tag: "ok", content: "" };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  let res = remove_dir_ffi(remove_dir_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
}

///|
#module("fs")
extern "js" fn remove_file_sync(path : String) -> Unit = "unlinkSync"

///|
extern "js" fn remove_file_ffi(
  remove_file : (String) -> Unit,
  path : String,
) -> FsUnitResult =
  #| function(removeFile, path) {
  #|  try {
  #|    removeFile(path);
  #|    return { tag: "ok", content: "" };
  #|  } catch (error) {
  #|    return { tag: "err", content: error.message };
  #|  }
  #| }

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  let res = remove_file_ffi(remove_file_sync, path)
  if !res.is_ok() {
    raise IOError(res.error_message())
  }
}

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
#module("fs")
extern "js" fn read_file_sync(path : String) -> Bytes = "readFileSync"

///|
extern "js" fn read_file_ffi(
  read_file : (String) -> Bytes,
  path : String,
) -> Int =
  #| function(readFile, path) {
  #|   try {
  #|     const content = readFile(path);
  #|     globalThis.fileContent = content;
  #|     return 0;
  #|   } catch (error) {
  #|     globalThis.errorMessage = error.message;
  #|     return -1;
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
) -> Int =
  #| function(writeFile, path, content) {
  #|   try {
  #|     writeFile(path, Buffer.from(content));
  #|     return 0;
  #|   } catch (error) {
  #|     globalThis.errorMessage = error.message;
  #|     return -1;
  #|   }
  #| }

///|
extern "js" fn get_file_content_ffi() -> Bytes =
  #| function() {
  #|   return globalThis.fileContent;
  #| }

///|
extern "js" fn get_dir_files_ffi() -> Array[String] =
  #| function() {
  #|   return globalThis.files;
  #| }

///|
extern "js" fn get_error_message_ffi() -> String =
  #| function() {
  #|   return globalThis.errorMessage || '';
  #| }

///|
fn read_file_to_bytes_internal(path : String) -> Bytes raise IOError {
  let res = read_file_ffi(read_file_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  get_file_content_ffi()
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
  if res == -1 {
    raise IOError(get_error_message_ffi())
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
) -> Int =
  #| function(readDir, path) {
  #|  try {
  #|    const files = readDir(path);
  #|    globalThis.files = files;
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn read_dir_internal(path : String) -> Array[String] raise IOError {
  let res = read_dir_ffi(read_dir_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  get_dir_files_ffi()
}

///|
#module("fs")
extern "js" fn create_dir_sync(path : String, options : FsOptions) -> Unit = "mkdirSync"

///|
extern "js" fn create_dir_ffi(
  create_dir : (String, FsOptions) -> Unit,
  path : String,
) -> Int =
  #| function(createDir, path) {
  #|  try {
  #|    createDir(path, { recursive: true });
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn create_dir_internal(path : String) -> Unit raise IOError {
  let res = create_dir_ffi(create_dir_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

///|
#module("fs")
extern "js" fn stat_sync(path : String) -> FsStats = "statSync"

///|
extern "js" fn is_dir_ffi(stat : (String) -> FsStats, path : String) -> Int =
  #| function(stat, path) {
  #|  try {
  #|    const stats = stat(path);
  #|    return stats.isDirectory() ? 1 : 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  let res = is_dir_ffi(stat_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  res == 1
}

///|
extern "js" fn is_file_ffi(stat : (String) -> FsStats, path : String) -> Int =
  #| function(stat, path) {
  #|  try {
  #|    const stats = stat(path);
  #|    return stats.isFile() ? 1 : 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  let res = is_file_ffi(stat_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  res == 1
}

///|
#module("fs")
extern "js" fn remove_dir_sync(path : String, options : FsOptions) -> Unit = "rmSync"

///|
extern "js" fn remove_dir_ffi(
  remove_dir : (String, FsOptions) -> Unit,
  path : String,
) -> Int =
  #| function(removeDir, path) {
  #|  try {
  #|    removeDir(path, { recursive: true });
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  let res = remove_dir_ffi(remove_dir_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

///|
#module("fs")
extern "js" fn remove_file_sync(path : String) -> Unit = "unlinkSync"

///|
extern "js" fn remove_file_ffi(
  remove_file : (String) -> Unit,
  path : String,
) -> Int =
  #| function(removeFile, path) {
  #|  try {
  #|    removeFile(path);
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  let res = remove_file_ffi(remove_file_sync, path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

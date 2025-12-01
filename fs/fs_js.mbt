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
extern "js" fn read_file_ffi(path : String) -> Int =
  #| function(path) {
  #|   var fs = require('fs');
  #|   try {
  #|     const content = fs.readFileSync(path);
  #|     globalThis.fileContent = content;
  #|     return 0;
  #|   } catch (error) {
  #|     globalThis.errorMessage = error.message;
  #|     return -1;
  #|   }
  #| }

///|
extern "js" fn write_file_ffi(path : String, content : Bytes) -> Int =
  #| function(path, content) {
  #|   var fs = require('fs');
  #|   try {
  #|     fs.writeFileSync(path, Buffer.from(content));
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
  let res = read_file_ffi(path)
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
  let res = write_file_ffi(path, content)
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
extern "js" fn path_exists_ffi(path : String) -> Bool =
  #| function(path) {
  #|  var fs = require('fs');
  #|  return fs.existsSync(path);
  #| }

///|
pub fn path_exists_internal(path : String) -> Bool {
  path_exists_ffi(path)
}

///|
extern "js" fn read_dir_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    const files = fs.readdirSync(path);
  #|    globalThis.files = files;
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn read_dir_internal(path : String) -> Array[String] raise IOError {
  let res = read_dir_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  get_dir_files_ffi()
}

///|
extern "js" fn create_dir_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    fs.mkdirSync(path, { recursive: true });
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn create_dir_internal(path : String) -> Unit raise IOError {
  let res = create_dir_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

///|
extern "js" fn is_dir_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    const stats = fs.statSync(path);
  #|    return stats.isDirectory() ? 1 : 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  let res = is_dir_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  res == 1
}

///|
extern "js" fn is_file_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    const stats = fs.statSync(path);
  #|    return stats.isFile() ? 1 : 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  let res = is_file_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  res == 1
}

///|
extern "js" fn remove_dir_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    fs.rmSync(path, { recursive: true });
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  let res = remove_dir_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

///|
extern "js" fn remove_file_ffi(path : String) -> Int =
  #| function(path) {
  #|  var fs = require('fs');
  #|  try {
  #|    fs.unlinkSync(path);
  #|    return 0;
  #|  } catch (error) {
  #|    globalThis.errorMessage = error.message;
  #|    return -1;
  #|  }
  #| }

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  let res = remove_file_ffi(path)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
}

///|

///|
extern "js" fn stat_details_ffi(path : String, out_buf : Bytes) -> Int =
  #| function(path, out_buf) {
  #|   var fs = require('fs');
  #|   try {
  #|     const s = fs.statSync(path, {bigint: true});
  #|     const view = new DataView(out_buf.buffer, out_buf.byteOffset, out_buf.byteLength);
  #|     
  #|     view.setBigUint64(0, s.dev, true);
  #|     view.setUint32(8, Number(s.mode), true);
  #|     view.setUint32(12, 0, true); // padding
  #|     view.setBigUint64(16, s.nlink, true);
  #|     view.setBigUint64(24, s.ino, true);
  #|     view.setUint32(32, Number(s.uid), true);
  #|     view.setUint32(36, Number(s.gid), true);
  #|     view.setBigUint64(40, s.rdev, true);
  #|     
  #|     const splitTime = (ns, offset) => {
  #|       if (ns === undefined) {
  #|         view.setBigInt64(offset, 0n, true);
  #|         view.setBigInt64(offset + 8, 0n, true);
  #|         return;
  #|       }
  #|       const sec = ns / 1000000000n;
  #|       const nsec = ns % 1000000000n;
  #|       view.setBigInt64(offset, sec, true);
  #|       view.setBigInt64(offset + 8, nsec, true);
  #|     };
  #|
  #|     splitTime(s.atimeNs, 48);
  #|     splitTime(s.mtimeNs, 64);
  #|     splitTime(s.ctimeNs, 80);
  #|     splitTime(s.birthtimeNs, 96);
  #|
  #|     view.setBigInt64(112, s.size, true);
  #|     view.setBigUint64(120, s.blocks || 0n, true);
  #|     view.setUint32(128, Number(s.blksize || 0), true);
  #|     view.setUint32(132, 0, true); // flags
  #|     view.setUint32(136, 0, true); // gen
  #|     view.setInt32(140, 0, true); // lspare
  #|     view.setBigInt64(144, 0n, true); // qspare
  #|     view.setBigInt64(152, 0n, true); // qspare
  #|
  #|     return 0;
  #|   } catch (error) {
  #|     globalThis.errorMessage = error.message;
  #|     return -1;
  #|   }
  #| }

///|
fn stat_internal(path : String) -> Stats raise IOError {
  let buf = Bytes::make(160, 0)
  let res = stat_details_ffi(path, buf)
  if res == -1 {
    raise IOError(get_error_message_ffi())
  }
  decode_stat(buf)
}

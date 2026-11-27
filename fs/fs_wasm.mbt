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
fn path_exists_internal(path : String) -> Bool {
  if path.contains("\u0000") {
    return false
  }
  // Only the status matters. A zero-field stat still follows the path.
  for ;; {
    let job = make_path_stat_job(
      path,
      path.length(),
      NO_STAT,
      STAT_HEADER_SIZE,
      invalid_parent_fd(),
      true,
    )
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    break error == 0
  }
}

///|
priv struct DirectoryBuffer(UInt64)

///|
#unsafe_skip_stub_check
fn DirectoryBuffer::new(len : Int32) -> DirectoryBuffer = "moonbitlang/async" "c_buffer/new"

///|
#unsafe_skip_stub_check
fn DirectoryBuffer::free(self : DirectoryBuffer) -> Unit = "moonbitlang/async" "c_buffer/free"

///|
#unsafe_skip_stub_check
fn make_readdir_job(
  dir : FileHandle,
  buffer : DirectoryBuffer,
  len : Int32,
  restart : Bool,
) -> FileJob = "moonbitlang/async" "thread_pool/make_readdir_job"

///|
#unsafe_skip_stub_check
fn entry_length(buffer : DirectoryBuffer, offset : Int32) -> Int32 = "moonbitlang/async" "fs/dir_entry_length"

///|
#unsafe_skip_stub_check
fn entry_name_offset(buffer : DirectoryBuffer, offset : Int32) -> Int32 = "moonbitlang/async" "fs/dir_entry_get_name_offset"

///|
#unsafe_skip_stub_check
fn entry_name_length(buffer : DirectoryBuffer, offset : Int32) -> Int32 = "moonbitlang/async" "fs/dir_entry_get_name_len"

///|
#unsafe_skip_stub_check
fn DirectoryBuffer::decoded_length(
  self : DirectoryBuffer,
  offset : Int32,
  len : Int32,
) -> Int32 = "moonbitlang/async" "os_string/decode_len"

///|
#unsafe_skip_stub_check
#borrow(output)
fn DirectoryBuffer::decode(
  self : DirectoryBuffer,
  offset : Int32,
  len : Int32,
  output : String,
  output_len : Int32,
) -> Unit = "moonbitlang/async" "os_string/decode"

///|
fn entry_name(buffer : DirectoryBuffer, offset : Int32, len : Int32) -> String {
  let units = buffer.decoded_length(offset, len)
  let name = String::make(units, '\u0000')
  buffer.decode(offset, len, name, units)
  name
}

///|
fn read_dir_internal(path : String) -> ArrayView[String] raise IOError {
  guard !path.contains("\u0000") else { raise IOError("read_dir: NUL in path") }
  let dir = open_legacy_handle(path, ACCESS_LIST_DIRECTORY)
  defer ignore(file_close_ffi(dir))
  let buffer = DirectoryBuffer::new(DIR_BUFFER_SIZE)
  defer buffer.free()
  let platform = file_host_platform()
  let names = []
  for ;; {
    let n = {
      let job = make_readdir_job(dir, buffer, DIR_BUFFER_SIZE, false)
      defer job.free()
      job.run()
      let error = job.err()
      if file_host_is_unix && error == UNIX_EINTR {
        continue
      }
      guard error == 0 else { raise file_error(error, "read_dir \{path}") }
      job.ret()
    }
    if n == 0 {
      break
    }
    append_dir_entries(names, buffer, n, platform)
  }
  names[:]
}

///|
fn is_file_internal(path : String) -> Bool raise IOError {
  kind(path) is Regular
}

///|
fn is_dir_internal(path : String) -> Bool raise IOError {
  kind(path) is Directory
}

///|
#unsafe_skip_stub_check
#borrow(path)
fn make_removeat_job(
  parent : FileHandle,
  path : String,
  path_len : Int32,
) -> FileJob = "moonbitlang/async" "thread_pool/make_removeat_job"

///|
fn remove_file_internal(path : String) -> Unit raise IOError {
  guard !path.contains("\u0000") else {
    raise IOError("remove_file: NUL in path")
  }
  let job = make_removeat_job(invalid_parent_fd(), path, path.length())
  defer job.free()
  job.run()
  let error = job.err()
  guard error == 0 else { raise file_error(error, "remove_file \{path}") }
}

///|
#unsafe_skip_stub_check
#borrow(path)
fn make_rmdir_job(path : String, path_len : Int32) -> FileJob = "moonbitlang/async" "thread_pool/make_rmdir_job"

///|
fn remove_dir_internal(path : String) -> Unit raise IOError {
  guard !path.contains("\u0000") else {
    raise IOError("remove_dir: NUL in path")
  }
  let job = make_rmdir_job(path, path.length())
  defer job.free()
  job.run()
  let error = job.err()
  guard error == 0 else { raise file_error(error, "remove_dir \{path}") }
}

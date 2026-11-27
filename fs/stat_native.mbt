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
#borrow(handle, fields)
extern "C" fn fstatx_sync(
  handle : FileHandle,
  request : UInt32,
  fields : FixedArray[Int64],
  len : Int32,
) -> Int32 = "moonbit_rt_fstatx_sync"

///|
extern "C" fn file_errno() -> Int32 = "moonbit_rt_get_errno"

///|
fn FileHandle::stat(
  self : FileHandle,
  request : UInt32,
  fields : FixedArray[Int64],
  context~ : String = "fstat",
) -> UInt32 raise @os_error.OsError {
  while fstatx_sync(self, request, fields, fields.length() * 8) < 0 {
    let error = file_errno()
    if !is_windows() && error == UNIX_EINTR {
      continue
    }
    raise @os_error.from_errno(error, context~)
  }
  (fields[0] >> 32).to_uint()
}

///|
#cfg(platform="windows")
extern "C" fn invalid_parent_fd() -> FileHandle = "moonbit_rt_get_invalid_handle"

///|
#cfg(not(platform="windows"))
fn invalid_parent_fd() -> FileHandle {
  FileHandle(-1)
}

///|
#owned(path, fields)
extern "C" fn make_path_stat_job(
  path : OsString,
  request : UInt32,
  fields : FixedArray[Int64],
  buf_len : Int32,
  parent : FileHandle,
  follow_symlink : Bool,
) -> FileJob = "moonbit_rt_make_statx_job"

///|
#cfg(platform="windows")
fn is_windows() -> Bool {
  true
}

///|
#cfg(not(platform="windows"))
fn is_windows() -> Bool {
  false
}

///|
fn stat_by_path(
  path : StringView,
  request : UInt32,
  follow_symlink : Bool,
  fields : FixedArray[Int64],
) -> UInt32 raise IOError {
  let job = make_path_stat_job(
    OsString::from_string(path),
    request,
    fields,
    fields.length() * 8,
    invalid_parent_fd(),
    follow_symlink,
  )
  ignore(job.execute_io("stat \{path}", retry_eintr=true))
  (fields[0] >> 32).to_uint()
}

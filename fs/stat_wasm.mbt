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
#unsafe_skip_stub_check
fn invalid_parent_fd() -> FileHandle = "moonbitlang/async" "fd_util/invalid_fd"

///|
#unsafe_skip_stub_check
#borrow(path)
fn make_path_stat_job(
  path : String,
  path_len : Int32,
  request : UInt32,
  buf_len : Int32,
  parent : FileHandle,
  follow_symlink : Bool,
) -> FileJob = "moonbitlang/async" "thread_pool/make_statx_job"

///|
// The host copies bytes into linear memory. An Int64 array gives us aligned
// little-endian words; the ABI takes its capacity in bytes.
#unsafe_skip_stub_check
#borrow(fields)
fn FileJob::copy_stat_words(
  self : FileJob,
  fields : FixedArray[Int64],
  len : Int32,
) -> Unit = "moonbitlang/async" "thread_pool/get_stat_result"

///|
fn is_windows() -> Bool {
  !file_host_is_unix
}

///|
fn stat_by_path(
  path : StringView,
  request : UInt32,
  follow_symlink : Bool,
  fields : FixedArray[Int64],
) -> UInt32 raise IOError {
  let path = path.to_owned()
  let len = fields.length() * 8
  for ;; {
    let job = make_path_stat_job(
      path,
      path.length(),
      request,
      len,
      invalid_parent_fd(),
      follow_symlink,
    )
    defer job.free()
    job.run()
    let error = job.err()
    if file_host_is_unix && error == UNIX_EINTR {
      continue
    }
    guard error == 0 else { raise file_error(error, "stat \{path}") }
    job.copy_stat_words(fields, len)
    guard fields[0].to_int() == len else {
      raise IOError("stat: invalid result length")
    }
    break (fields[0] >> 32).to_uint()
  }
}

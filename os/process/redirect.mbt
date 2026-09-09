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
#borrow(path, status)
extern "c" fn native_open(
  path : Bytes,
  output : Int,
  append : Int,
  create_mode : Int,
  permission : Int,
  status : FixedArray[Int],
) -> Int64 = "moonbit_community_unix_process_open"

///|
extern "c" fn native_close(handle : Int64) -> Unit = "moonbit_community_unix_process_close"

///|
#borrow(handles)
extern "c" fn native_pipe(handles : FixedArray[Int64]) -> Int = "moonbit_community_unix_process_pipe"

///|
/// An eagerly opened, one-shot input redirection. Close it explicitly if it will
/// not be passed to a child. close() is idempotent.
pub struct ProcessInput {
  priv mut handle : Int64
}

///|
/// An eagerly opened output redirection. One-shot by default; shared outputs
/// remain open until explicitly closed. close() is idempotent.
pub struct ProcessOutput {
  priv mut handle : Int64
  priv shared : Bool
}

///|
pub fn ProcessInput::close(self : ProcessInput) -> Unit {
  if self.handle != -1L {
    native_close(self.handle)
    self.handle = -1L
  }
}

///|
pub fn ProcessOutput::close(self : ProcessOutput) -> Unit {
  if self.handle != -1L {
    native_close(self.handle)
    self.handle = -1L
  }
}

///|
fn ProcessOutput::after_spawn(self : ProcessOutput) -> Unit {
  if !self.shared {
    self.close()
  }
}

///|
fn ProcessInput::fd(self : ProcessInput) -> Int64 raise @os_error.OSError {
  if self.handle == -1L {
    @ffi.closed_handle("spawn_orphan: input redirection is already closed")
  }
  self.handle
}

///|
fn ProcessOutput::fd(self : ProcessOutput) -> Int64 raise @os_error.OSError {
  if self.handle == -1L {
    @ffi.closed_handle("spawn_orphan: output redirection is already closed")
  }
  self.handle
}

///|
/// Open a file for the stdin of one child. The path is resolved now, relative to
/// the parent's cwd, independently of the child's cwd option.
pub fn redirect_from_file(
  path : String,
) -> ProcessInput raise @os_error.OSError {
  validate_string(path)
  let status = FixedArray::make(1, 0)
  let handle = native_open(cstr(path), 0, 0, 0, 0, status)
  if status[0] != 0 {
    fail("redirect_from_file", path, status[0])
  }
  { handle, }
}

///|
/// Open an output file using fs.CreateMode. A one-shot output closes after the
/// spawn attempt, even on failure, and can serve both stdout and stderr of that
/// child. A shared output can serve multiple children; close it after the last
/// spawn. Unused outputs also need explicit closing. Windows ignores permission.
pub fn redirect_to_file(
  path : String,
  append? : Bool = false,
  create_mode? : @fs.CreateMode = CreateOrTruncate,
  permission? : Int = 0o644,
  shared? : Bool = false,
) -> ProcessOutput raise @os_error.OSError {
  validate_string(path)
  let mode = match create_mode {
    OpenExisting => 0
    TruncateExisting => 1
    OpenOrCreate => 2
    CreateOrTruncate => 3
    CreateNew => 4
  }
  let status = FixedArray::make(1, 0)
  let handle = native_open(
    cstr(path),
    1,
    if append {
      1
    } else {
      0
    },
    mode,
    permission,
    status,
  )
  if status[0] != 0 {
    fail("redirect_to_file", path, status[0])
  }
  { handle, shared, }
}

///|
fn capture_pipe() -> (ProcessInput, ProcessOutput) raise @os_error.OSError {
  let handles = FixedArray::make(2, -1L)
  let code = native_pipe(handles)
  if code != 0 {
    fail("collect_output", "creating capture pipe", code)
  }
  ({ handle: handles[0], }, { handle: handles[1], shared: false, })
}

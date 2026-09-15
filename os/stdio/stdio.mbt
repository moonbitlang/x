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
/// The standard input stream. Operations use its current process handle.
/// This value does not own or close the underlying handle.
pub struct Input {
  priv stream : Int
}

///|
/// A standard output stream. Operations use its current process handle.
/// This value does not own or close the underlying handle.
pub struct Output {
  priv stream : Int
}

///|
/// The current process's standard input.
pub let stdin : Input = { stream: 0, }

///|
/// The current process's standard output.
pub let stdout : Output = { stream: 1, }

///|
/// The current process's standard error output.
pub let stderr : Output = { stream: 2, }

///|
/// Read until EOF, preserving all bytes. This blocks until input ends.
/// Read failures raise OSError instead of returning partial input.
pub fn Input::read_all(self : Input) -> Bytes raise @os_error.OSError {
  let status = FixedArray::make(1, 0)
  let bytes = @ffi.stdio_read_all(self.stream, status)
  if status[0] != 0 {
    raise OSError(status[0], context="stdin.read_all")
  }
  bytes
}

///|
/// Write the complete byte view directly to the stream, without adding a newline
/// or changing its encoding. An empty view is a no-op.
/// This may block. Returned I/O failures raise OSError; a prefix may already have
/// been written. On POSIX, the process's SIGPIPE disposition applies: a broken
/// pipe can terminate the process unless the caller handles or ignores SIGPIPE.
pub fn Output::write(
  self : Output,
  bytes : BytesView,
) -> Unit raise @os_error.OSError {
  let context = if self.stream == 1 { "stdout.write" } else { "stderr.write" }
  let data = bytes.data()
  defer ignore(data) // Capture errno before releasing the borrowed buffer.
  if @ffi.stdio_write(self.stream, data, bytes.start_offset(), bytes.length()) <
    0 {
    @os_error.check_errno(context)
  }
}

///|
/// Whether this stream is attached to a terminal.
/// Returns false for redirected, invalid, or unqueryable streams.
pub fn Input::is_terminal(self : Input) -> Bool {
  @ffi.stdio_is_terminal(self.stream) != 0
}

///|
/// Whether this stream is attached to a terminal.
/// Returns false for redirected, invalid, or unqueryable streams.
pub fn Output::is_terminal(self : Output) -> Bool {
  @ffi.stdio_is_terminal(self.stream) != 0
}

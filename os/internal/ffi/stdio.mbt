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

// Stream numbers are 0 for stdin, 1 for stdout, and 2 for stderr.
// The public stdio types keep these numbers private.

///|
#borrow(status)
pub extern "c" fn stdio_read_all(
  stream : Int,
  status : FixedArray[Int],
) -> Bytes = "moonbit_community_unix_stdio_read_all"

///|
/// The byte range must be valid. Returns -1 on failure, preserving the OS error.
#borrow(bytes)
pub extern "c" fn stdio_write(
  stream : Int,
  bytes : Bytes,
  offset : Int,
  len : Int,
) -> Int = "moonbit_community_unix_stdio_write"

///|
pub extern "c" fn stdio_is_terminal(stream : Int) -> Int = "moonbit_community_unix_stdio_is_terminal"

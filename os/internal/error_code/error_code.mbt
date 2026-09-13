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

// Native codes shared by OSError predicates and argument validation. These
// POSIX errno values are the same on Linux and macOS. Windows aliases refer to
// GetLastError codes, matching the Unix-shaped API's predicate names.

///|
pub let errno_ENOENT : Int = 2 // ENOENT / ERROR_FILE_NOT_FOUND

///|
#cfg(not(platform="windows"))
pub let errno_EEXIST : Int = 17

///|
#cfg(platform="windows")
pub let errno_EEXIST : Int = 183 // ERROR_ALREADY_EXISTS

///|
#cfg(not(platform="windows"))
pub let errno_EACCES : Int = 13

///|
#cfg(platform="windows")
pub let errno_EACCES : Int = 5 // ERROR_ACCESS_DENIED

///|
#cfg(not(platform="windows"))
pub let errno_ENOTDIR : Int = 20

///|
#cfg(platform="windows")
pub let errno_ENOTDIR : Int = 267 // ERROR_DIRECTORY

///|
pub const EINTR : Int = 4

///|
#cfg(not(platform="windows"))
pub let errno_EINVAL : Int = 22

///|
#cfg(platform="windows")
pub let errno_EINVAL : Int = 87 // ERROR_INVALID_PARAMETER

///|
#cfg(not(platform="windows"))
pub let errno_EBADF : Int = 9

///|
#cfg(platform="windows")
pub let errno_EBADF : Int = 6 // ERROR_INVALID_HANDLE

///|
#cfg(not(platform="windows"))
pub let invalid_data : Int = 5 // EIO

///|
#cfg(platform="windows")
pub let invalid_data : Int = 13 // ERROR_INVALID_DATA

///|
pub const ERROR_PATH_NOT_FOUND : Int = 3

///|
pub const ERROR_FILE_EXISTS : Int = 80

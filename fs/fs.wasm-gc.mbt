// Copyright 2024 International Digital Economy Academy
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

/// Reads the contents of a file into a string.
///
/// # Parameters
/// - `path`: An `XExternString` representing the file path.
///
/// # Returns
/// An `XExternString` containing the file contents.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn read_file_to_string(path : @ffi.XExternString) -> @ffi.XExternString = "__moonbit_fs_unstable" "read_file_to_string"

/// Writes a string to a file.
///
/// # Parameters
/// - `path`: An `XExternString` representing the file path.
/// - `content`: An `XExternString` containing the content to be written to the file.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn _write_string(path : @ffi.XExternString, content : @ffi.XExternString) = "__moonbit_fs_unstable" "write_string_to_file"

/// Checks if a path exists.
///
/// # Parameters
/// - `path`: An `XExternString` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn path_exists(path : @ffi.XExternString) -> Bool = "__moonbit_fs_unstable" "path_exists"

fn _read_to_string(path : String) -> String {
  let content = read_file_to_string(@ffi.string_to_extern(path))
  @ffi.string_from_extern(content)
}

/// Writes a string to a file.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
/// - `content`: A `String` containing the content to be written to the file.
pub fn write_string(~path : String, ~content : String) -> Unit {
  _write_string(@ffi.string_to_extern(path), @ffi.string_to_extern(content))
}

/// Checks if a path exists.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
pub fn exists(~path : String) -> Bool {
  path_exists(@ffi.string_to_extern(path))
}

/// Reads the entire contents of a file into a string.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A `String` containing the file contents if the file exists, otherwise raises an error.
pub fn read_to_string(~path : String) -> String! {
  if not(exists(~path)) {
    fail!("File does not exist")
  }
  _read_to_string(path)
}

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


/// Writes a string to a file.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
/// - `content`: A `String` containing the content to be written to the file.
pub fn write_string(~path : String, ~content : String) -> Unit {
  @ffi.write_string((path), (content))
}

pub fn write_bytes(~path : String, ~content : Array[Byte]) -> Unit {
  @ffi.write_bytes(path, content)
}

/// Checks if a path exists.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
pub fn path_exists(~path : String) -> Bool {
  @ffi.path_exists((path))
}

/// Reads the entire contents of a file into a string.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A `String` containing the file contents if the file exists, otherwise raises an error.
pub fn read_to_string(~path : String) -> String! {
  if not(path_exists(~path)) {
    fail!("File does not exist")
  }
  @ffi.read_file_to_string(path)
}

pub fn read_to_bytes(~path : String) -> Array[Byte]! {
  if not(path_exists(~path)) {
    fail!("file `\{path}` does not exist")
  }
  @ffi.read_file_to_bytes((path))
}

pub fn read_dir(~path : String) -> Array[String]! {
  if not(path_exists(~path)) {
    fail!("dir `\{path}` does not exist")
  }
  @ffi.read_dir(path)
}

pub fn create_dir(~path : String) -> Unit {
  @ffi.create_dir(path)
}

pub fn is_dir(~path : String) -> Bool {
  @ffi.is_dir(path)
}

pub fn is_file(~path : String) -> Bool {
  @ffi.is_file(path)
}

pub fn remove_dir(~path : String) -> Unit! {
  if not(path_exists(~path)) {
    fail!("dir `\{path}` does not exist")
  }
  if not(is_dir(~path)) {
    fail!("path `\{path}` is not a directory")
  }
  @ffi.remove_dir(path)
}

pub fn remove_file(~path : String) -> Unit! {
  if not(path_exists(~path)) {
    fail!("file `\{path}` does not exist")
  }
  if not(is_file(~path)) {
    fail!("path `\{path}` is not a file")
  }
  @ffi.remove_file(path)
}


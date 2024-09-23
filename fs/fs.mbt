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

/// Writes an array of bytes to a file at the specified path.
///
/// # Parameters
///
/// - `path` : The path to the file where the bytes will be written.
/// - `content` : An array of bytes to be written to the file.
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

/// Reads the content of a file specified by the given path and returns its
/// content as an array of bytes. If the file does not exist, an error is raised.
///
/// # Parameters
///
/// - `path` : The path to the file to be read.
///
/// # Returns
///
/// - An array of bytes representing the content of the file.
pub fn read_to_bytes(~path : String) -> Array[Byte]! {
  if not(path_exists(~path)) {
    fail!("file `\{path}` does not exist")
  }
  @ffi.read_file_to_bytes((path))
}

/// Reads the contents of a directory and returns an array of filenames.
///
/// # Parameters
///
/// - `path` : The path to the directory to be read.
///
/// # Returns
///
/// - An array of strings representing the file name and directory name in the directory.
pub fn read_dir(~path : String) -> Array[String]! {
  if not(path_exists(~path)) {
    fail!("dir `\{path}` does not exist")
  }
  @ffi.read_dir(path)
}

/// Creates a directory at the specified path.
///
/// # Parameters
///
/// - `path` : The path where the directory should be created.
pub fn create_dir(~path : String) -> Unit {
  @ffi.create_dir(path)
}

/// Checks if the given path is a directory.
///
/// # Parameters
///
/// - `path` : The string representing the path to be checked.
///
/// # Returns
///
/// - `Bool` : `true` if the path is a directory, `false` otherwise.
pub fn is_dir(~path : String) -> Bool {
  @ffi.is_dir(path)
}

/// Check if the given path points to a file.
///
/// # Parameters
///
/// - `path` : The string representing the path to be checked.
///
/// # Returns
///
/// - `Bool` : `true` if the path points to a file, `false` otherwise.
pub fn is_file(~path : String) -> Bool {
  @ffi.is_file(path)
}

/// Removes a directory at the specified path.
///
/// # Parameters
///
/// - `path` : The string path to the directory that needs to be removed.
pub fn remove_dir(~path : String) -> Unit! {
  if not(path_exists(~path)) {
    fail!("dir `\{path}` does not exist")
  }
  if not(is_dir(~path)) {
    fail!("path `\{path}` is not a directory")
  }
  @ffi.remove_dir(path)
}

/// Removes a file at the specified path.
///
/// # Parameters
///
/// - `path` : The path to the file that needs to be removed.
pub fn remove_file(~path : String) -> Unit! {
  if not(path_exists(~path)) {
    fail!("file `\{path}` does not exist")
  }
  if not(is_file(~path)) {
    fail!("path `\{path}` is not a file")
  }
  @ffi.remove_file(path)
}


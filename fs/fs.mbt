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
#derive(Debug)
pub(all) suberror IOError {
  IOError(String)
}

///|
#cfg(any(target="native", target="wasm"))
fn IOError::from_os_error(err : @os_error.OsError) -> IOError {
  let OsError(_, raw_code~, ..) = err
  IOError("\{err} (\{raw_code})")
}

///|
/// MoonBit byte buffers have signed 32-bit lengths.
#cfg(any(target="native", target="wasm", target="js"))
const MAX_FILE_BYTES : Int32 = 0x7fffffff

///|
/// Reads the content of a file specified by the given path and returns its
/// content as `Bytes`
///
/// # Parameters
///
/// - `path` : The path to the file to be read.
///
/// # Returns
///
/// - A `Bytes` representing the content of the file.
pub fn read_file_to_bytes(path : String) -> Bytes raise IOError {
  read_file_to_bytes_internal(path)
}

///|
/// Reads the content of a file specified by the given path and returns its
/// content as `String`.
///
/// # Parameters
///
/// - `path` : The path to the file to be read.
/// - `encoding~` : The encoding of the file. Only support `utf8` for now.
///
/// # Returns
///
/// - A `String` representing the content of the file.
pub fn read_file_to_string(
  path : String,
  encoding~ : String = "utf8",
) -> String raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  @utf8.decode_lossy(read_file_to_bytes(path))
}

///|
/// Writes a `Bytes` to a file at the specified path.
///
/// # Parameters
///
/// - `path` : The path to the file where the bytes will be written.
/// - `content` : A `Bytes` to be written to the file.
pub fn write_bytes_to_file(
  path : String,
  content : Bytes,
) -> Unit raise IOError {
  write_bytes_to_file_internal(path, content)
}

///|
/// Writes a `String` to a file at the specified path.
///
/// # Parameters
///
/// - `path` : The path to the file where the string will be written.
/// - `content` : A `String` to be written to the file.
/// - `encoding~` : The encoding of the file. Only support `utf8` for now.
pub fn write_string_to_file(
  path : String,
  content : String,
  encoding~ : String = "utf8",
) -> Unit raise IOError {
  guard encoding == "utf8" else {
    raise IOError(
      "Unsupported encoding: \{encoding}, only utf8 is supported for now",
    )
  }
  write_bytes_to_file(path, @utf8.encode(content))
}

///|
/// Checks if a path exists.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
pub fn path_exists(path : String) -> Bool {
  path_exists_internal(path)
}

///|
/// Reads the contents of a directory and returns a read-only view of filenames.
/// On the `wasm` target, invalid sequences in filenames are decoded as U+FFFD.
///
/// # Parameters
///
/// - `path` : The path to the directory to be read.
///
/// # Returns
///
/// - A view of strings representing the file names and directory names in the directory.
///   Use `to_owned()` to copy the view into a mutable array.
pub fn read_dir(path : String) -> ArrayView[String] raise IOError {
  read_dir_internal(path)
}

///|
#cfg(any(target="native", target="wasm"))
const ACCESS_LIST_DIRECTORY : Int32 = 3

///|
#cfg(any(target="native", target="wasm"))
const DIR_BUFFER_SIZE : Int32 = 8192

///|
#cfg(any(target="native", target="wasm"))
fn append_dir_entries(
  names : Array[String],
  buffer : DirectoryBuffer,
  batch_result : Int32,
  platform : @types.Platform,
) -> Unit raise IOError {
  for offset = 0, count = 1 {
    let length = entry_length(buffer, offset)
    let name = entry_name(
      buffer,
      offset + entry_name_offset(buffer, offset),
      entry_name_length(buffer, offset),
    )
    if name != "." && name != ".." {
      names.push(name)
    }
    let next = offset + length
    let last = match platform {
      Linux => next >= batch_result // getdents64 returns bytes
      MacOS => count >= batch_result // getattrlistbulk returns entries
      Windows => length == 0 // the last entry has no successor
      @types.Platform::.. => raise IOError("unsupported directory entry format")
    }
    if last {
      break
    }
    continue next, count + 1
  }
}

///|
/// Creates a directory at the specified path.
/// Note: nested directories are not supported for native backend
///
/// # Parameters
///
/// - `path` : The path where the directory should be created.
/// - `mode~` : The mode of the directory. Default is `777`.
pub fn create_dir(path : String) -> Unit raise IOError {
  create_dir_internal(path)
}

///|
/// Checks if the given path is a directory.
///
/// # Parameters
///
/// - `path` : The string representing the path to be checked.
///
/// # Returns
///
/// - `Bool` : `true` if the path is a directory, `false` otherwise.
pub fn is_dir(path : String) -> Bool raise IOError {
  is_dir_internal(path)
}

///|
/// Check if the given path points to a file.
///
/// # Parameters
///
/// - `path` : The string representing the path to be checked.
///
/// # Returns
///
/// - `Bool` : `true` if the path points to a file, `false` otherwise.
pub fn is_file(path : String) -> Bool raise IOError {
  is_file_internal(path)
}

///|
/// Removes a directory at the specified path.
/// On the `wasm` target, the directory must be empty.
///
/// # Parameters
///
/// - `path` : The string path to the directory that needs to be removed.
pub fn remove_dir(path : String) -> Unit raise IOError {
  remove_dir_internal(path)
}

///|
/// Removes a file at the specified path.
/// On the `wasm` target, this also accepts an empty directory.
///
/// # Parameters
///
/// - `path` : The path to the file that needs to be removed.
pub fn remove_file(path : String) -> Unit raise IOError {
  remove_file_internal(path)
}

///|
#deprecated
pub extend IOError with Debug::{to_repr}

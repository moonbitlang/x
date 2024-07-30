/// Reads the contents of a file into a string.
///
/// # Parameters
/// - `path`: An `ExternString` representing the file path.
///
/// # Returns
/// An `ExternString` containing the file contents.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn read_file_to_string(path : @ffi.ExternString) -> @ffi.ExternString = "__moonbit_fs_unstable" "read_file_to_string"

/// Writes a string to a file.
///
/// # Parameters
/// - `path`: An `ExternString` representing the file path.
/// - `content`: An `ExternString` containing the content to be written to the file.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn write_string_to_file(path : @ffi.ExternString, content : @ffi.ExternString) = "__moonbit_fs_unstable" "write_string_to_file"

/// Checks if a path exists.
///
/// # Parameters
/// - `path`: An `ExternString` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
///
/// # Note
/// This is an unstable function call and should be used internally only.
fn path_exists(path : @ffi.ExternString) -> Bool = "__moonbit_fs_unstable" "path_exists"

fn read_to_string(path : String) -> String {
  let content = read_file_to_string(@ffi.string_to_extern(path))
  @ffi.string_from_extern(content)
}

/// Writes a string to a file.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
/// - `content`: A `String` containing the content to be written to the file.
pub fn write_to_string(path : String, content : String) -> Unit {
  write_string_to_file(
    @ffi.string_to_extern(path),
    @ffi.string_to_extern(content),
  )
}

/// Checks if a path exists.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A boolean indicating whether the path exists.
pub fn exists(path : String) -> Bool {
  path_exists(@ffi.string_to_extern(path))
}

/// Reads the entire contents of a file into a string.
///
/// # Parameters
/// - `path`: A `String` representing the file path.
///
/// # Returns
/// A `String` containing the file contents if the file exists, otherwise raises an error.
pub fn read_all(path : String) -> String! {
  if not(exists(path)) {
    fail!("File does not exist")
  }
  read_to_string(path)
}

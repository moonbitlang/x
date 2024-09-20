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
pub fn read_file_to_string(path: String) -> String {
  read_to_string_internal(path)
}
extern "js" fn read_to_string_internal(path: String) -> String =
  #| function(path) {
  #|  fs = require('fs');
  #|  let content = fs.readFileSync(path, 'utf8');
  #|  return content;
  #| }


test {
  let a = read_file_to_string("1.txt")
  println(a)
}

pub fn read_file_to_bytes(path : String) -> Array[Byte] {
  Array::from_fixed_array(read_file_to_bytes_internal(path))
  
}

extern "js" fn read_file_to_bytes_internal(path: String) -> FixedArray[Byte] =
  #| function(path) {
  #|  fs = require('fs');
  #|  let content = fs.readFileSync(path);
  #|  return content;
  #| }

test {
  let a = read_file_to_bytes("1.txt").map(fn (x) { x.to_uint() })
  println(a)
}

// /// Writes a string to a file.
// ///
// /// # Parameters
// /// - `path`: An `XExternString` representing the file path.
// /// - `content`: An `XExternString` containing the content to be written to the file.
// ///
// /// # Note
// /// This is an unstable function call and should be used internally only.
pub fn write_string(path: String, content: String) -> Unit {
  write_string_internal(path, content)
}

extern "js" fn write_string_internal(path: String, content: String) =
  #| function(path, content) {
  #|  fs = require('fs');
  #|  fs.writeFileSync(path, content, 'utf8');
  #| }

test {
  write_string("test.txt", "Hello, World!")
  let content = read_file_to_string("test.txt")
  println(content)
}

pub fn write_bytes(path: String, content: Array[Byte]) -> Unit {
  
  write_bytes_internal(path, FixedArray::from_array(content))
}

extern "js" fn write_bytes_internal(path: String, content: FixedArray[Byte]) =
  #| function(path, content) {
  #|  fs = require('fs');
  #|  fs.writeFileSync(path, Buffer.from(content));
  #| }

test {
  let bytes = [72, 101, 108, 108, 111].map(fn(x) { x.to_byte() })
  write_bytes("test_bytes.txt", bytes)
  let content = read_file_to_string("test_bytes.txt")
  println(content)
}

// /// Checks if a path exists.
// ///
// /// # Parameters
// /// - `path`: An `XExternString` representing the file path.
// ///
// /// # Returns
// /// A boolean indicating whether the path exists.
// ///
// /// # Note
// /// This is an unstable function call and should be used internally only.
pub fn path_exists(path: String) -> Bool {
  path_exists_internal(path)
}

extern "js" fn path_exists_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.existsSync(path);
  #| }

test {
  let exists = path_exists("test.txt")
  println("test.txt exists: " + exists.to_string())
  
  let not_exists = path_exists("non_existent_file.txt")
  println("non_existent_file.txt exists: " + not_exists.to_string())
}

pub fn read_dir(path: String) -> Array[String] {
  Array::from_fixed_array(read_dir_internal(path))
}

extern "js" fn read_dir_internal(path: String) -> FixedArray[String] =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.readdirSync(path);
  #| }

test {
  println(read_dir("num"))
}

pub fn create_dir(path: String) -> Unit {
  create_dir_internal(path)
}

extern "js" fn create_dir_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.mkdirSync(path, { recursive: true });
  #| }


test {
  create_dir("zzzz/hhh")
}

pub fn is_dir(path: String) -> Bool {
  is_dir_internal(path)
}

extern "js" fn is_dir_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.statSync(path).isDirectory();
  #| }

test {
  assert_true!(is_dir("num"))
  assert_false!(is_dir("test.txt"))
}


pub fn is_file(path: String) -> Bool {
  is_file_internal(path)
}

extern "js" fn is_file_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.statSync(path).isFile();
  #| }

test {
  assert_true!(is_file("test.txt"))
  assert_false!(is_file("num"))
}

pub fn remove_dir(path: String) -> Unit {
  remove_dir_internal(path)
}

extern "js" fn remove_dir_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.rmSync(path, { recursive: true });
  #| }

test {
  remove_dir("zzzz")
}

pub fn remove_file(path: String) -> Unit {
  remove_file_internal(path)
}

extern "js" fn remove_file_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.unlinkSync(path);
  #| }

test {
  remove_file("1.txt")
}
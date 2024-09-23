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


pub fn read_file_to_string(path: String) -> String {
  read_to_string_internal(path)
}
extern "js" fn read_to_string_internal(path: String) -> String =
  #| function(path) {
  #|  fs = require('fs');
  #|  let content = fs.readFileSync(path, 'utf8');
  #|  return content;
  #| }


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

pub fn write_string(path: String, content: String) -> Unit {
  write_string_internal(path, content)
}

extern "js" fn write_string_internal(path: String, content: String) =
  #| function(path, content) {
  #|  fs = require('fs');
  #|  fs.writeFileSync(path, content, 'utf8');
  #| }

pub fn write_bytes(path: String, content: Array[Byte]) -> Unit {
  write_bytes_internal(path, FixedArray::from_array(content))
}

extern "js" fn write_bytes_internal(path: String, content: FixedArray[Byte]) =
  #| function(path, content) {
  #|  fs = require('fs');
  #|  fs.writeFileSync(path, Buffer.from(content));
  #| }

pub fn path_exists(path: String) -> Bool {
  path_exists_internal(path)
}

extern "js" fn path_exists_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.existsSync(path);
  #| }

pub fn read_dir(path: String) -> Array[String] {
  Array::from_fixed_array(read_dir_internal(path))
}

extern "js" fn read_dir_internal(path: String) -> FixedArray[String] =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.readdirSync(path);
  #| }

pub fn create_dir(path: String) -> Unit {
  create_dir_internal(path)
}

extern "js" fn create_dir_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.mkdirSync(path, { recursive: true });
  #| }

pub fn is_dir(path: String) -> Bool {
  is_dir_internal(path)
}

extern "js" fn is_dir_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.statSync(path).isDirectory();
  #| }

pub fn is_file(path: String) -> Bool {
  is_file_internal(path)
}

extern "js" fn is_file_internal(path: String) -> Bool =
  #| function(path) {
  #|  fs = require('fs');
  #|  return fs.statSync(path).isFile();
  #| }

pub fn remove_dir(path: String) -> Unit {
  remove_dir_internal(path)
}

extern "js" fn remove_dir_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.rmSync(path, { recursive: true });
  #| }

pub fn remove_file(path: String) -> Unit {
  remove_file_internal(path)
}

extern "js" fn remove_file_internal(path: String) -> Unit =
  #| function(path) {
  #|  fs = require('fs');
  #|  fs.unlinkSync(path);
  #| }

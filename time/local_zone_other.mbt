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
pub fn local_zone() -> Zone raise Error {
  fail("OS timezone loading requires the native backend")
}

///|
test "local zone loading reports unsupported backends" {
  try local_zone() catch {
    _ => ()
  } noraise {
    _ => fail("Expected unsupported backend")
  }
}

///|
// Imports cannot yet be conditional; UTF-8 decoding is used by native readers.
let _unused_native_utf8_import : Unit = ignore(@utf8.decode_lossy(b""))

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
/// An OS failure while loading the system local timezone.
/// The code is a Win32 error on Windows and `errno` on Unix. The message is
/// supplied by the OS and can be empty when no description is available.
/// Malformed timezone data is reported separately by the timezone decoder.
#warnings("-unused_constructor")
pub suberror LocalZoneError {
  LocalZoneError(UInt, context~ : String, message~ : String)
}

///|
pub impl Show for LocalZoneError with fn output(self, logger) -> Unit {
  let LocalZoneError(code, context~, message~) = self
  if message.is_empty() {
    logger <+ "LocalZoneError(\{context}, OS error \{code})"
  } else {
    logger <+ "LocalZoneError(\{context}: \{message}, OS error \{code})"
  }
}

///|
pub extend LocalZoneError with Show::{to_string, output}

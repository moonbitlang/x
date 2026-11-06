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
/// An operating-system failure, following async's error-code/context model.
/// The code is errno on Unix, GetLastError on native Windows, and the signed
/// libuv errno returned by Node.js on JS. Codes are backend/platform specific.
/// The legacy whole-file APIs continue to raise IOError.
pub(all) suberror OSError {
  OSError(Int32, context~ : String)
}

///|
pub impl Show for OSError with fn output(self, logger) {
  let OSError(code, context~) = self
  let message = "\{context}: \{os_error_message(code)}"
  logger <+ "OSError(\{Repr(message)})"
}

///|
pub impl Debug for OSError with fn to_repr(self) {
  let OSError(code, context~) = self
  Repr::opaque_(
    "@fs.OSError",
    Repr::string("\{context}: \{os_error_message(code)}"),
  )
}

///|
pub extend OSError with Show::{to_string, output}

///|
pub extend OSError with Debug::{to_repr}

///|
/// An exact-length read reached EOF before filling the requested buffer,
/// matching async's ReaderClosed. Bytes already read still advance the cursor.
pub(all) suberror ReaderClosed

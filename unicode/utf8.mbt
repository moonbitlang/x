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
/// Encode a string into UTF-8 bytes.
///
/// Deprecated: this duplicates `@encoding/utf8.encode` from
/// `moonbitlang/core/encoding/utf8`.
#deprecated("Use `@utf8.encode` from `moonbitlang/core/encoding/utf8` instead")
pub fn to_utf8_bytes(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
/// Decode UTF-8 bytes into a string, replacing malformed sequences with
/// U+FFFD.
///
/// Deprecated: this duplicates `@encoding/utf8.decode_lossy` from
/// `moonbitlang/core/encoding/utf8`.
#deprecated("Use `@utf8.decode_lossy` from `moonbitlang/core/encoding/utf8` instead")
pub fn to_utf8_string(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes)
}

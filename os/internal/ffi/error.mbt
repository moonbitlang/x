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
pub fn invalid_argument(context : String) -> Unit raise @os_error.OSError {
  raise OSError(@error_code.errno_EINVAL, context~)
}

///|
pub fn closed_handle(context : String) -> Unit raise @os_error.OSError {
  raise OSError(@error_code.errno_EBADF, context~)
}

///|
pub fn invalid_data(context : String) -> Unit raise @os_error.OSError {
  raise OSError(@error_code.invalid_data, context~)
}

///|
pub fn validate_string(
  value : StringView,
  context : String,
) -> Unit raise @os_error.OSError {
  if value.code_units().contains(0) {
    invalid_argument(context + ": NUL is not allowed")
  }
}

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

#ifdef _WIN32
#include "moonbit.h"
#include <windows.h>

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_windows_path_is_dir(moonbit_string_t path) {
  DWORD attrs = GetFileAttributesW((LPCWSTR)path);
  if (attrs == INVALID_FILE_ATTRIBUTES) return -(int64_t)GetLastError();
  return (attrs & FILE_ATTRIBUTE_DIRECTORY) != 0;
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_windows_remove_file(moonbit_string_t path) {
  return DeleteFileW((LPCWSTR)path) ? 0 : -(int64_t)GetLastError();
}
#endif

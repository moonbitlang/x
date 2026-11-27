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

#ifndef _WIN32
#define _FILE_OFFSET_BITS 64
#endif
#include "moonbit.h"
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
typedef HANDLE file_handle_t;

// Use full write access even for an append handle: the caller can also request
// truncation or FlushFileBuffers. The append itself selects EOF atomically.
MOONBIT_FFI_EXPORT HANDLE moonbitlang_x_open_windows_file(
    moonbit_string_t path, int32_t mode, int32_t create_mode, int32_t sync,
    int32_t *error) {
  static const DWORD access[] = {
      GENERIC_READ, GENERIC_WRITE, GENERIC_READ | GENERIC_WRITE};
  static const DWORD creation[] = {
      OPEN_EXISTING, TRUNCATE_EXISTING, OPEN_ALWAYS, CREATE_ALWAYS, CREATE_NEW};
  HANDLE handle = CreateFileW((LPCWSTR)path, access[mode],
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      creation[create_mode], FILE_ATTRIBUTE_NORMAL | (sync ? FILE_FLAG_WRITE_THROUGH : 0),
      NULL);
  if (handle == INVALID_HANDLE_VALUE) *error = (int32_t)GetLastError();
  return handle;
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_append_windows_file(
    HANDLE handle, const uint8_t *buffer, int32_t offset, int32_t len) {
  OVERLAPPED at = {0};
  at.Offset = at.OffsetHigh = 0xffffffff;
  DWORD count;
  if (!WriteFile(handle, buffer + offset, (DWORD)len, &count, &at))
    return -(int64_t)GetLastError();
  return count;
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_windows_file_size(HANDLE handle) {
  LARGE_INTEGER size;
  return GetFileSizeEx(handle, &size) ? size.QuadPart : -(int64_t)GetLastError();
}
#else
#include <errno.h>
#include <unistd.h>
typedef int file_handle_t;
#endif

// The legacy whole-file reader uses SEEK_END, including for special files.
MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_legacy_length(file_handle_t handle) {
#ifdef _WIN32
  LARGE_INTEGER zero = {0}, end;
  return SetFilePointerEx(handle, zero, &end, FILE_END) ? end.QuadPart : -(int64_t)GetLastError();
#else
  off_t end = lseek(handle, 0, SEEK_END);
  return end < 0 ? -(int64_t)errno : (int64_t)end;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_close(file_handle_t handle) {
  // Never retry close: the descriptor may already have been released.
#ifdef _WIN32
  return CloseHandle(handle) ? 0 : -(int64_t)GetLastError();
#else
  return close(handle) < 0 ? -(int64_t)errno : 0;
#endif
}

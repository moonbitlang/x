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

// Synchronous subset of moonbitlang/async file operations at
// 6c3c4c886f63318e15450d15a4cd5d3016f09449.
#ifndef _WIN32
#define _FILE_OFFSET_BITS 64
#endif
#include "moonbit.h"
#include <stdint.h>
#include <errno.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_open(
#ifdef _WIN32
    moonbit_string_t path,
#else
    moonbit_bytes_t path,
#endif
    int32_t writing) {
#ifdef _WIN32
  HANDLE handle = CreateFileW(
      (LPCWSTR)path, writing ? GENERIC_WRITE : GENERIC_READ,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      writing ? CREATE_ALWAYS : OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    return -(int64_t)GetLastError();
  }
  return (int64_t)(intptr_t)handle;
#else
  int flags = (writing ? O_WRONLY | O_CREAT | O_TRUNC : O_RDONLY) | O_CLOEXEC;
  int fd = open((const char *)path, flags, 0666);
  return fd < 0 ? -(int64_t)errno : fd;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_read(int64_t handle,
    uint8_t *buffer, int32_t offset, int32_t len) {
#ifdef _WIN32
  OVERLAPPED at = {0};
  at.Offset = (DWORD)offset;
  DWORD count;
  if (!ReadFile((HANDLE)(intptr_t)handle, buffer + offset, (DWORD)len, &count, &at)) {
    DWORD error = GetLastError();
    return error == ERROR_HANDLE_EOF ? 0 : -(int64_t)error;
  }
  return count;
#else
  ssize_t count;
  do {
    count = pread((int)handle, buffer + offset, (size_t)len, (off_t)offset);
  } while (count < 0 && errno == EINTR);
  return count < 0 ? -(int64_t)errno : (int64_t)count;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_write(int64_t handle,
    const uint8_t *buffer, int32_t offset, int32_t len) {
#ifdef _WIN32
  DWORD count;
  if (!WriteFile((HANDLE)(intptr_t)handle, buffer + offset, (DWORD)len, &count, NULL)) {
    return -(int64_t)GetLastError();
  }
  return count;
#else
  ssize_t count;
  do {
    count = write((int)handle, buffer + offset, (size_t)len);
  } while (count < 0 && errno == EINTR);
  return count < 0 ? -(int64_t)errno : (int64_t)count;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_length(int64_t handle) {
#ifdef _WIN32
  LARGE_INTEGER zero = {0}, end;
  if (!SetFilePointerEx((HANDLE)(intptr_t)handle, zero, &end, FILE_END)) {
    return -(int64_t)GetLastError();
  }
  return end.QuadPart;
#else
  off_t end = lseek((int)handle, 0, SEEK_END);
  return end < 0 ? -(int64_t)errno : (int64_t)end;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_close(int64_t handle) {
  // Never retry close: the descriptor may already have been released.
#ifdef _WIN32
  return CloseHandle((HANDLE)(intptr_t)handle) ? 0 : -(int64_t)GetLastError();
#else
  return close((int)handle) < 0 ? -(int64_t)errno : 0;
#endif
}

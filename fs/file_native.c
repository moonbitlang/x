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

// Mode and positioned-I/O conventions follow moonbitlang/async's fs.c and thread_pool.c
// at 6c3c4c886f63318e15450d15a4cd5d3016f09449.
// No worker, cancellation, or private runtime job layout is used here.

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
#include <sys/stat.h>
#include <unistd.h>
#endif

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_open(
#ifdef _WIN32
    moonbit_string_t path,
#else
    moonbit_bytes_t path,
#endif
    int32_t mode, int32_t create_mode, int32_t append, int32_t permission,
    int32_t sync) {
#ifdef _WIN32
  static const DWORD access[] = {
      GENERIC_READ, GENERIC_WRITE, GENERIC_READ | GENERIC_WRITE};
  static const DWORD creation[] = {
      OPEN_EXISTING, TRUNCATE_EXISTING, OPEN_ALWAYS, CREATE_ALWAYS, CREATE_NEW};
  DWORD desired = access[mode];
  // Keep GENERIC_WRITE for TRUNCATE_EXISTING/CREATE_ALWAYS. Appending uses
  // WriteFile's atomic end-of-file offset instead of a seek followed by write.
  HANDLE handle = CreateFileW(
      (LPCWSTR)path, desired,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
      creation[create_mode],
      FILE_ATTRIBUTE_NORMAL | (sync ? FILE_FLAG_WRITE_THROUGH : 0), NULL);
  if (handle == INVALID_HANDLE_VALUE) {
    return -(int64_t)GetLastError();
  }
  return (int64_t)(intptr_t)handle;
#else
  static const int access[] = {O_RDONLY, O_WRONLY, O_RDWR};
  static const int creation[] = {
      0, O_TRUNC, O_CREAT, O_CREAT | O_TRUNC, O_CREAT | O_EXCL};
  int flags = access[mode] | creation[create_mode] | O_CLOEXEC;
  if (append) flags |= O_APPEND;
#ifdef __APPLE__
  if (sync) flags |= O_SYNC;
#else
  if (sync == 1) flags |= O_DSYNC;
  if (sync == 2) flags |= O_SYNC;
#endif
  int fd = open((const char *)path, flags, (mode_t)permission);
  return fd < 0 ? -(int64_t)errno : fd;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_read(int64_t handle,
    uint8_t *buffer, int32_t offset, int32_t len, int64_t position) {
#ifdef _WIN32
  OVERLAPPED at = {0};
  at.Offset = (DWORD)position;
  at.OffsetHigh = (DWORD)((uint64_t)position >> 32);
  DWORD count;
  if (!ReadFile((HANDLE)(intptr_t)handle, buffer + offset, (DWORD)len, &count, &at)) {
    DWORD error = GetLastError();
    return error == ERROR_HANDLE_EOF ? 0 : -(int64_t)error;
  }
  return count;
#else
  ssize_t count;
  do {
    count = pread((int)handle, buffer + offset, (size_t)len, (off_t)position);
  } while (count < 0 && errno == EINTR);
  return count < 0 ? -(int64_t)errno : (int64_t)count;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_write(int64_t handle,
    const uint8_t *buffer, int32_t offset, int32_t len, int64_t position) {
#ifdef _WIN32
  OVERLAPPED at = {0};
  // -1 requests atomic append; -2 preserves legacy sequential writes.
  // Neither sentinel is accepted as a caller-supplied file offset.
  at.Offset = (DWORD)position;
  at.OffsetHigh = (DWORD)((uint64_t)position >> 32);
  DWORD count;
  if (!WriteFile((HANDLE)(intptr_t)handle, buffer + offset, (DWORD)len, &count,
                position == -2 ? NULL : &at)) {
    return -(int64_t)GetLastError();
  }
  return count;
#else
  ssize_t count;
  do {
    count = position < 0
        ? write((int)handle, buffer + offset, (size_t)len)
        : pwrite((int)handle, buffer + offset, (size_t)len, (off_t)position);
  } while (count < 0 && errno == EINTR);
  return count < 0 ? -(int64_t)errno : (int64_t)count;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_size(int64_t handle) {
#ifdef _WIN32
  LARGE_INTEGER size;
  if (!GetFileSizeEx((HANDLE)(intptr_t)handle, &size)) {
    return -(int64_t)GetLastError();
  }
  return size.QuadPart;
#else
  struct stat info;
  if (fstat((int)handle, &info) < 0) {
    return -(int64_t)errno;
  }
  if (!S_ISREG(info.st_mode)) {
    return -(int64_t)EINVAL;
  }
  return (int64_t)info.st_size;
#endif
}

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_legacy_length(int64_t handle) {
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

MOONBIT_FFI_EXPORT int64_t moonbitlang_x_file_sync(int64_t handle, int32_t only_data) {
#ifdef _WIN32
  return FlushFileBuffers((HANDLE)(intptr_t)handle) ? 0 : -(int64_t)GetLastError();
#else
#ifdef __APPLE__
  int result = fsync((int)handle);
#else
  int result = only_data ? fdatasync((int)handle) : fsync((int)handle);
#endif
  return result < 0 ? -(int64_t)errno : 0;
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

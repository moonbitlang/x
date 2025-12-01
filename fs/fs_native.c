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

#ifdef __cplusplus
extern "C" {
#endif

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <stdint.h>

#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#else
#include <dirent.h>
#include <unistd.h>
#endif

#include "moonbit.h"

MOONBIT_FFI_EXPORT FILE *moonbitlang_x_fs_fopen_ffi(moonbit_bytes_t path,
                                                    moonbit_bytes_t mode) {
  return fopen((const char *)path, (const char *)mode);
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_is_null(void *ptr) {
  return ptr == NULL;
}

MOONBIT_FFI_EXPORT size_t moonbitlang_x_fs_fread_ffi(moonbit_bytes_t ptr,
                                                     int size, int nitems,
                                                     FILE *stream) {
  return fread(ptr, size, nitems, stream);
}

MOONBIT_FFI_EXPORT size_t moonbitlang_x_fs_fwrite_ffi(moonbit_bytes_t ptr,
                                                      int size, int nitems,
                                                      FILE *stream) {
  return fwrite(ptr, size, nitems, stream);
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_fseek_ffi(FILE *stream, long offset,
                                                  int whence) {
  return fseek(stream, offset, whence);
}

MOONBIT_FFI_EXPORT long moonbitlang_x_fs_ftell_ffi(FILE *stream) {
  return ftell(stream);
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_fflush_ffi(FILE *file) {
  return fflush(file);
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_fclose_ffi(FILE *stream) {
  return fclose(stream);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbitlang_x_fs_get_error_message(void) {
  const char *err_str = strerror(errno);
  size_t len = strlen(err_str);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, err_str, len);
  return bytes;
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_stat_ffi(moonbit_bytes_t path) {
  struct stat buffer;
  int status = stat((const char *)path, &buffer);
  return status;
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_is_dir_ffi(moonbit_bytes_t path) {
#ifdef _WIN32
  DWORD attrs = GetFileAttributes((const char *)path);
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    return -1;
  }
  if (attrs & FILE_ATTRIBUTE_DIRECTORY) {
    return 1;
  }
  return 0;
#else
  struct stat buffer;
  int status = stat((const char *)path, &buffer);
  if (status == -1) {
    return -1;
  }
  if (S_ISDIR(buffer.st_mode)) {
    return 1;
  }
  return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_is_file_ffi(moonbit_bytes_t path) {
#ifdef _WIN32
  DWORD attrs = GetFileAttributes((const char *)path);
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    return -1;
  }
  if (!(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
    return 1;
  }
  return 0;
#else
  struct stat buffer;
  int status = stat((const char *)path, &buffer);
  if (status == -1) {
    return -1;
  }
  if (S_ISREG(buffer.st_mode)) {
    return 1;
  }
  return 0;
#endif
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_remove_dir_ffi(moonbit_bytes_t path) {
#ifdef _WIN32
  return _rmdir((const char *)path);
#else
  return rmdir((const char *)path);
#endif
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_remove_file_ffi(moonbit_bytes_t path) {
  return remove((const char *)path);
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_create_dir_ffi(moonbit_bytes_t path) {
#ifdef _WIN32
  return _mkdir((const char *)path);
#else
  return mkdir((const char *)path, 0777);
#endif
}

MOONBIT_FFI_EXPORT moonbit_bytes_t *
moonbitlang_x_fs_read_dir_ffi(moonbit_bytes_t path) {
#ifdef _WIN32
  WIN32_FIND_DATA find_data;
  HANDLE dir;
  moonbit_bytes_t *result = NULL;
  int count = 0;

  size_t path_len = strlen((const char *)path);
  char *search_path = malloc(path_len + 3);
  if (search_path == NULL) {
    return NULL;
  }

  sprintf(search_path, "%s\\*", (const char *)path);
  dir = FindFirstFile(search_path, &find_data);
  if (dir == INVALID_HANDLE_VALUE) {
    DWORD error = GetLastError();
    fprintf(stderr, "Failed to open directory: error code %lu\n", error);
    free(search_path);
    return NULL;
  }

  do {
    if (strcmp(find_data.cFileName, ".") != 0 &&
        strcmp(find_data.cFileName, "..") != 0) {
      count++;
    }
  } while (FindNextFile(dir, &find_data));

  FindClose(dir);
  dir = FindFirstFile(search_path, &find_data);
  free(search_path);

  result = (moonbit_bytes_t *)moonbit_make_ref_array(count, NULL);
  if (result == NULL) {
    FindClose(dir);
    return NULL;
  }

  int index = 0;
  do {
    if (strcmp(find_data.cFileName, ".") != 0 &&
        strcmp(find_data.cFileName, "..") != 0) {
      size_t name_len = strlen(find_data.cFileName);
      moonbit_bytes_t item = moonbit_make_bytes(name_len, 0);
      memcpy(item, find_data.cFileName, name_len);
      result[index++] = item;
    }
  } while (FindNextFile(dir, &find_data));

  FindClose(dir);
  return result;
#else

  DIR *dir;
  struct dirent *entry;
  moonbit_bytes_t *result = NULL;
  int count = 0;

  // open the directory
  dir = opendir((const char *)path);
  if (dir == NULL) {
    perror("opendir");
    return NULL;
  }

  // first traversal of the directory, calculate the number of items
  while ((entry = readdir(dir)) != NULL) {
    // ignore only . and ..
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    count++;
  }

  // reset the directory stream
  rewinddir(dir);

  // create moonbit_ref_array to store the result
  result = (moonbit_bytes_t *)moonbit_make_ref_array(count, NULL);
  if (result == NULL) {
    closedir(dir);
    return NULL;
  }

  // second traversal of the directory, fill the array
  int index = 0;
  while ((entry = readdir(dir)) != NULL) {
    // ignore only . and ..
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    size_t name_len = strlen(entry->d_name);
    moonbit_bytes_t item = moonbit_make_bytes(name_len, 0);
    memcpy(item, entry->d_name, name_len);
    result[index++] = item;
  }

  closedir(dir);
  return result;
#endif
}

MOONBIT_FFI_EXPORT int moonbitlang_x_fs_stat_details_ffi(moonbit_bytes_t path,
                                                         moonbit_bytes_t out_buf) {
  struct stat s;
  if (stat((const char *)path, &s) != 0) {
    return -1;
  }

  int32_t type = 3; // Unknown
#ifdef _WIN32
  if (s.st_mode & _S_IFREG)
    type = 0;
  else if (s.st_mode & _S_IFDIR)
    type = 1;
#else
  if (S_ISREG(s.st_mode))
    type = 0;
  else if (S_ISDIR(s.st_mode))
    type = 1;
  else if (S_ISLNK(s.st_mode))
    type = 2;
#endif

  uint64_t dev = (uint64_t)s.st_dev;
  uint32_t mode = (uint32_t)s.st_mode;
  uint64_t nlink = (uint64_t)s.st_nlink;
  uint64_t ino = (uint64_t)s.st_ino;
  uint32_t uid = (uint32_t)s.st_uid;
  uint32_t gid = (uint32_t)s.st_gid;
  uint64_t rdev = (uint64_t)s.st_rdev;
  int64_t size = (int64_t)s.st_size;

#if defined(__APPLE__)
  int64_t atime_sec = s.st_atimespec.tv_sec;
  int64_t atime_nsec = s.st_atimespec.tv_nsec;
  int64_t mtime_sec = s.st_mtimespec.tv_sec;
  int64_t mtime_nsec = s.st_mtimespec.tv_nsec;
  int64_t ctime_sec = s.st_ctimespec.tv_sec;
  int64_t ctime_nsec = s.st_ctimespec.tv_nsec;
  int64_t birthtime_sec = s.st_birthtimespec.tv_sec;
  int64_t birthtime_nsec = s.st_birthtimespec.tv_nsec;
#elif defined(_WIN32)
  int64_t atime_sec = s.st_atime;
  int64_t atime_nsec = 0;
  int64_t mtime_sec = s.st_mtime;
  int64_t mtime_nsec = 0;
  int64_t ctime_sec = s.st_ctime;
  int64_t ctime_nsec = 0;
  int64_t birthtime_sec = 0;
  int64_t birthtime_nsec = 0;
#else
  // Linux and others
  int64_t atime_sec = s.st_atim.tv_sec;
  int64_t atime_nsec = s.st_atim.tv_nsec;
  int64_t mtime_sec = s.st_mtim.tv_sec;
  int64_t mtime_nsec = s.st_mtim.tv_nsec;
  int64_t ctime_sec = s.st_ctim.tv_sec;
  int64_t ctime_nsec = s.st_ctim.tv_nsec;
  int64_t birthtime_sec = 0;
  int64_t birthtime_nsec = 0;
#endif

#ifdef _WIN32
  uint64_t blocks = 0;
  uint32_t blksize = 0;
  uint32_t flags = 0;
  uint32_t gen = 0;
#else
  uint64_t blocks = (uint64_t)s.st_blocks;
  uint32_t blksize = (uint32_t)s.st_blksize;
  #if defined(__APPLE__)
    uint32_t flags = (uint32_t)s.st_flags;
    uint32_t gen = (uint32_t)s.st_gen;
  #else
    uint32_t flags = 0;
    uint32_t gen = 0;
  #endif
#endif

  uint8_t *buf = (uint8_t *)out_buf;
  // dev (8 bytes) at offset 0
  memcpy(buf, &dev, 8);
  // mode (4 bytes) at offset 8
  memcpy(buf + 8, &mode, 4);
  // padding (4 bytes) at offset 12
  memset(buf + 12, 0, 4);
  // nlink (8 bytes) at offset 16
  memcpy(buf + 16, &nlink, 8);
  // ino (8 bytes) at offset 24
  memcpy(buf + 24, &ino, 8);
  // uid (4 bytes) at offset 32
  memcpy(buf + 32, &uid, 4);
  // gid (4 bytes) at offset 36
  memcpy(buf + 36, &gid, 4);
  // rdev (8 bytes) at offset 40
  memcpy(buf + 40, &rdev, 8);
  // atime (sec, nsec) at offset 48, 56
  memcpy(buf + 48, &atime_sec, 8);
  memcpy(buf + 56, &atime_nsec, 8);
  // mtime (sec, nsec) at offset 64, 72
  memcpy(buf + 64, &mtime_sec, 8);
  memcpy(buf + 72, &mtime_nsec, 8);
  // ctime (sec, nsec) at offset 80, 88
  memcpy(buf + 80, &ctime_sec, 8);
  memcpy(buf + 88, &ctime_nsec, 8);
  // birthtime (sec, nsec) at offset 96, 104
  memcpy(buf + 96, &birthtime_sec, 8);
  memcpy(buf + 104, &birthtime_nsec, 8);
  // size (8 bytes) at offset 112
  memcpy(buf + 112, &size, 8);
  // blocks (8 bytes) at offset 120
  memcpy(buf + 120, &blocks, 8);
  // blksize (4 bytes) at offset 128
  memcpy(buf + 128, &blksize, 4);
  // flags (4 bytes) at offset 132
  memcpy(buf + 132, &flags, 4);
  // gen (4 bytes) at offset 136
  memcpy(buf + 136, &gen, 4);
  // lspare (4 bytes) at offset 140 -> 0
  memset(buf + 140, 0, 4);
  // qspare (16 bytes) at offset 144 -> 0
  memset(buf + 144, 0, 16);

  return 0;
}

#ifdef __cplusplus
}
#endif

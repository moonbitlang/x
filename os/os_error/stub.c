#include <stdint.h>
#include <string.h>
#include <moonbit.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#endif

// Internal indices shared only by this module's MoonBit wrappers.
MOONBIT_FFI_EXPORT int32_t moonbit_unix_error_code(int32_t kind) {
#ifdef _WIN32
  switch (kind) {
    case 1: return ERROR_FILE_NOT_FOUND;
    case 2: return ERROR_ALREADY_EXISTS;
    case 3: return ERROR_ACCESS_DENIED;
    case 4: return ERROR_DIRECTORY;
    case 5: return 0;
    case 6: return ERROR_INVALID_PARAMETER;
    case 7: return ERROR_INVALID_HANDLE;
    default: return ERROR_INVALID_DATA;
  }
#else
  switch (kind) {
    case 1: return ENOENT;
    case 2: return EEXIST;
    case 3: return EACCES;
    case 4: return ENOTDIR;
    case 5: return EINTR;
    case 6: return EINVAL;
    case 7: return EBADF;
    default: return EIO;
  }
#endif
}

MOONBIT_FFI_EXPORT int32_t moonbit_unix_error_matches(int32_t code, int32_t kind) {
#ifdef _WIN32
  if (kind == 1) return code == ERROR_FILE_NOT_FOUND || code == ERROR_PATH_NOT_FOUND;
  if (kind == 2) return code == ERROR_FILE_EXISTS || code == ERROR_ALREADY_EXISTS;
  if (kind == 5) return 0;
#endif
  return code != 0 && code == moonbit_unix_error_code(kind);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_unix_error_message(int32_t code) {
#ifdef _WIN32
  wchar_t *message = NULL;
  DWORD length = FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
      FORMAT_MESSAGE_IGNORE_INSERTS, NULL, (DWORD)code, 0, (wchar_t *)&message, 0, NULL);
  int n = length ? WideCharToMultiByte(CP_UTF8, 0, message, (int)length, NULL, 0, NULL, NULL) : 0;
  moonbit_bytes_t out = moonbit_make_bytes(n, 0);
  if (n) WideCharToMultiByte(CP_UTF8, 0, message, (int)length, (char *)out, n, NULL, NULL);
  if (message) LocalFree(message);
#else
  const char *message = strerror(code);
  size_t length = message ? strlen(message) : 0;
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)length, 0);
  if (length) memcpy(out, message, length);
#endif
  return out;
}

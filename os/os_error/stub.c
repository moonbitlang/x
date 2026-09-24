#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <moonbit.h>
#ifdef _WIN32
#include <windows.h>
#endif

MOONBIT_FFI_EXPORT int32_t moonbit_unix_get_errno(void) {
#ifdef _WIN32
  return (int32_t)GetLastError();
#else
  return errno;
#endif
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

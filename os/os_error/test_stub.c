// Set the thread-local native error deterministically for check_errno tests.
#include <stdint.h>
#include <errno.h>
#include <moonbit.h>
#ifdef _WIN32
#include <windows.h>
#endif

MOONBIT_FFI_EXPORT void moonbit_unix_test_set_errno(int32_t code) {
#ifdef _WIN32
  SetLastError((DWORD)code);
#else
  errno = code;
#endif
}

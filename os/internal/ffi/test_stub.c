// Windows regression fixture: a junction whose display label is not its target.
typedef int moon_unix_fs_test_tu_marker;
#ifdef _WIN32
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <winioctl.h>

int32_t moon_unix_test_junction(const uint16_t *path, const uint16_t *target, int32_t as_volume) {
  const wchar_t *destination = (const wchar_t *)target;
  wchar_t mount[MAX_PATH], volume[MAX_PATH];
  if (as_volume) {
    if (!GetVolumePathNameW(destination, mount, MAX_PATH) ||
        !GetVolumeNameForVolumeMountPointW(mount, volume, MAX_PATH)) return (int32_t)GetLastError();
    destination = volume + 4; // replace the Win32 extended prefix with the NT prefix below
  }
  const wchar_t display[] = L"display-only";
  size_t units = wcslen(destination);
  // The substitute name uses the NT namespace; the print name is independent.
  size_t substitute_bytes = (units + 4) * sizeof(wchar_t);
  size_t print_offset = substitute_bytes + sizeof(wchar_t);
  size_t size = 16 + print_offset + sizeof(display);
  if (size > MAXIMUM_REPARSE_DATA_BUFFER_SIZE) return ERROR_BUFFER_OVERFLOW;
  uint8_t *buffer = (uint8_t *)calloc(size, 1);
  if (!buffer) return ERROR_NOT_ENOUGH_MEMORY;
  DWORD tag = IO_REPARSE_TAG_MOUNT_POINT;
  USHORT payload = (USHORT)(size - 8);
  USHORT fields[4] = {0, (USHORT)substitute_bytes,
                     (USHORT)print_offset, (USHORT)(sizeof(display) - sizeof(wchar_t))};
  const wchar_t prefix[4] = {0x5c, L'?', L'?', 0x5c};
  memcpy(buffer, &tag, sizeof(tag));
  memcpy(buffer + 4, &payload, sizeof(payload));
  memcpy(buffer + 8, fields, sizeof(fields));
  memcpy(buffer + 16, prefix, sizeof(prefix));
  memcpy(buffer + 16 + sizeof(prefix), destination, units * sizeof(wchar_t));
  memcpy(buffer + 16 + print_offset, display, sizeof(display));
  HANDLE handle = CreateFileW((const wchar_t *)path, GENERIC_WRITE,
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING,
      FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, NULL);
  int32_t error = 0;
  if (handle == INVALID_HANDLE_VALUE) error = (int32_t)GetLastError();
  else {
    DWORD written = 0;
    if (!DeviceIoControl(handle, FSCTL_SET_REPARSE_POINT, buffer, (DWORD)size,
                         NULL, 0, &written, NULL)) error = (int32_t)GetLastError();
    if (!CloseHandle(handle) && error == 0) error = (int32_t)GetLastError();
  }
  free(buffer);
  return error;
}
#endif

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

#include <moonbit.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#include <wchar.h>
#ifdef _MSC_VER
#pragma comment(lib, "advapi32.lib")
#endif

/* Independent Win32 conversion oracle for the native integration test. */
MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_local_offset(int64_t second, int32_t year) {
  DYNAMIC_TIME_ZONE_INFORMATION zone;
  SYSTEMTIME utc, local;
  FILETIME file;
  ULARGE_INTEGER ticks, local_ticks;
  /* FILETIME's supported range; this helper is only used by bounded tests. */
  if (second < -11644473600LL || second > 253402300799LL) return INT32_MIN;
  ticks.QuadPart = (uint64_t)(second + 11644473600LL) * 10000000;
  file.dwLowDateTime = ticks.LowPart;
  file.dwHighDateTime = ticks.HighPart;
  if (GetDynamicTimeZoneInformation(&zone) == TIME_ZONE_ID_INVALID ||
      !FileTimeToSystemTime(&file, &utc)) return INT32_MIN;
  /* Tests supply the local year so dates straddling New Year use the right
   * rule. This converter is also available on Windows 7. */
  TIME_ZONE_INFORMATION rule;
  if (!GetTimeZoneInformationForYear((USHORT)year, &zone, &rule) ||
      !SystemTimeToTzSpecificLocalTime(&rule, &utc, &local)) return INT32_MIN;
  if (!SystemTimeToFileTime(&local, &file)) return INT32_MIN;
  local_ticks.LowPart = file.dwLowDateTime;
  local_ticks.HighPart = file.dwHighDateTime;
  return (int32_t)(((int64_t)local_ticks.QuadPart - (int64_t)ticks.QuadPart) / 10000000);
}

/* Owned by MoonBit. Accessors keep native layout and alignment in C.
 * The current zone stays captured while each annual API result is read out. */
typedef struct {
  DYNAMIC_TIME_ZONE_INFORMATION current;
  TIME_ZONE_INFORMATION rule;
} windows_timezone;

MOONBIT_FFI_EXPORT windows_timezone *moonbitlang_x_time_windows_current_zone(uint32_t *error) {
  windows_timezone *zone = (windows_timezone *)moonbit_make_bytes(sizeof(*zone), 0);
  if (GetDynamicTimeZoneInformation(&zone->current) == TIME_ZONE_ID_INVALID) {
    *error = GetLastError();
    return zone;
  }
  zone->rule.Bias = zone->current.Bias;
  zone->rule.StandardBias = zone->current.StandardBias;
  zone->rule.DaylightBias = zone->current.DaylightBias;
  zone->rule.StandardDate = zone->current.StandardDate;
  zone->rule.DaylightDate = zone->current.DaylightDate;
  *error = ERROR_SUCCESS;
  return zone;
}

MOONBIT_FFI_EXPORT moonbit_string_t moonbitlang_x_time_windows_zone_name(const windows_timezone *zone) {
  moonbit_string_t name = moonbit_make_string(128, 0);
  memcpy(name, zone->current.TimeZoneKeyName, 256);
  return name;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_dynamic_disabled(const windows_timezone *zone) {
  return zone->current.DynamicDaylightTimeDisabled != 0;
}

/* Windows 7 fallback: only year-range discovery needs registry access.
 * Annual rules still come from GetTimeZoneInformationForYear below. */
MOONBIT_FFI_EXPORT uint32_t moonbitlang_x_time_windows_registry_years(
    windows_timezone *zone, uint32_t *years) {
  WCHAR path[256];
  int length = swprintf(path, 256,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Time Zones\\%ls\\Dynamic DST",
      zone->current.TimeZoneKeyName);
  if (length < 0 || length >= 256) return ERROR_INSUFFICIENT_BUFFER;
  HKEY key;
  LSTATUS error = RegOpenKeyExW(HKEY_LOCAL_MACHINE, path, 0, KEY_READ, &key);
  if (error != ERROR_SUCCESS) return error;
  const WCHAR *fields[] = {L"FirstEntry", L"LastEntry"};
  for (int i = 0; i < 2; i++) {
    DWORD type = 0, size = sizeof(DWORD), year = 0;
    error = RegQueryValueExW(key, fields[i], NULL, &type, (BYTE *)&year, &size);
    if (error != ERROR_SUCCESS) break;
    if (type != REG_DWORD || size != sizeof(DWORD)) {
      error = ERROR_INVALID_DATA;
      break;
    }
    years[i] = year;
  }
  LSTATUS close_error = RegCloseKey(key);
  return error != ERROR_SUCCESS ? error : close_error;
}

MOONBIT_FFI_EXPORT uint32_t moonbitlang_x_time_windows_zone_years(
    windows_timezone *zone, uint32_t *years) {
  /* Advapi32 is already loaded through the registry imports. Detect the
   * Windows 8 API by export, keeping this binary loadable on Windows 7. */
  HMODULE module = GetModuleHandleW(L"advapi32.dll");
  if (!module) return GetLastError();
  typedef DWORD (WINAPI *effective_years_fn)(
      PDYNAMIC_TIME_ZONE_INFORMATION, PDWORD, PDWORD);
  union {
    FARPROC address;
    effective_years_fn function;
  } entry = {GetProcAddress(module, "GetDynamicTimeZoneInformationEffectiveYears")};
  effective_years_fn effective_years = entry.function;
  if (!effective_years) {
    DWORD error = GetLastError();
    if (error != ERROR_PROC_NOT_FOUND) return error;
    return moonbitlang_x_time_windows_registry_years(zone, years);
  }
  DWORD first, last;
  DWORD error = effective_years(&zone->current, &first, &last);
  if (error == ERROR_SUCCESS) {
    years[0] = first;
    years[1] = last;
  }
  return error;
}

MOONBIT_FFI_EXPORT moonbit_string_t moonbitlang_x_time_local_zone_error_message(uint32_t code) {
  WCHAR *message = NULL;
  DWORD length = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL, code, 0, (WCHAR *)&message, 0, NULL);
  /* An unavailable message must not replace the original error code. */
  moonbit_string_t result = moonbit_make_string((int)length, 0);
  if (length) memcpy(result, message, length * sizeof(WCHAR));
  if (message) LocalFree(message);
  return result;
}

MOONBIT_FFI_EXPORT uint32_t moonbitlang_x_time_windows_zone_rule(
    windows_timezone *zone, int32_t year) {
  if (!GetTimeZoneInformationForYear((USHORT)year, &zone->current, &zone->rule))
    return GetLastError();
  return ERROR_SUCCESS;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_bias(const windows_timezone *zone) {
  return zone->rule.Bias;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_standard_bias(const windows_timezone *zone) {
  return zone->rule.StandardBias;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_daylight_bias(const windows_timezone *zone) {
  return zone->rule.DaylightBias;
}

static const SYSTEMTIME *windows_transition_date(const windows_timezone *zone, int32_t daylight) {
  return daylight ? &zone->rule.DaylightDate : &zone->rule.StandardDate;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_year(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wYear;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_month(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wMonth;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_weekday(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wDayOfWeek;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_day(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wDay;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_hour(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wHour;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_minute(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wMinute;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_second(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wSecond;
}

MOONBIT_FFI_EXPORT int32_t moonbitlang_x_time_windows_date_millisecond(
    const windows_timezone *zone, int32_t daylight) {
  return windows_transition_date(zone, daylight)->wMilliseconds;
}

#else
#include <errno.h>
#include <limits.h>
#include <unistd.h>

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbitlang_x_time_local_zone_path(
    const uint8_t *input, uint32_t *error) {
  char path[PATH_MAX];
  if (!realpath((const char *)input, path)) {
    *error = errno;
    return moonbit_make_bytes(0, 0);
  }
  *error = 0;
  int length = (int)strlen(path);
  moonbit_bytes_t result = moonbit_make_bytes(length, 0);
  memcpy(result, path, (size_t)length);
  return result;
}

/* Keep file ownership and errno capture next to the OS calls. The caller
 * chooses the path, derives its zone ID, and turns error codes into errors. */
MOONBIT_FFI_EXPORT moonbit_bytes_t moonbitlang_x_time_read_zone_file(
    const uint8_t *path, uint32_t *error) {
  moonbit_bytes_t data = NULL;
  *error = 0;
  FILE *file = fopen((const char *)path, "rb");
  if (!file) { *error = errno; goto done; }
  if (fseek(file, 0, SEEK_END) != 0) { *error = errno; goto done; }
  long size = ftell(file);
  if (size < 0) { *error = errno; goto done; }
  if (size > INT32_MAX) { *error = EFBIG; goto done; }
  if (fseek(file, 0, SEEK_SET) != 0) { *error = errno; goto done; }
  data = moonbit_make_bytes((int)size, 0);
  if (fread(data, 1, (size_t)size, file) != (size_t)size) {
    *error = ferror(file) ? errno : EIO;
    goto done;
  }
  int next = fgetc(file);
  if (ferror(file)) *error = errno;
  else if (next != EOF) *error = EIO; /* File size changed during the read. */
done:
  if (file && fclose(file) != 0 && *error == 0) *error = errno;
  if (*error != 0) {
    if (data) moonbit_decref(data);
    return moonbit_make_bytes(0, 0);
  }
  return data;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbitlang_x_time_local_zone_error_message(uint32_t code) {
  const char *message = strerror((int)code);
  int length = (int)strlen(message);
  moonbit_bytes_t result = moonbit_make_bytes(length, 0);
  memcpy(result, message, (size_t)length);
  return result;
}
#endif

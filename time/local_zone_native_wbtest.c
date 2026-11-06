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

#include <stdint.h>

#ifdef _WIN32
#include <moonbit.h>
#include <windows.h>

/* Compare the MoonBit snapshot with Win32's conversion in the configured zone. */
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
#endif

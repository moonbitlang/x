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

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(path, error)
extern "C" fn local_zone_path(path : Bytes, error : Ref[UInt]) -> Bytes = "moonbitlang_x_time_local_zone_path"

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(path, error)
extern "C" fn read_zone_file(path : Bytes, error : Ref[UInt]) -> Bytes = "moonbitlang_x_time_read_zone_file"

///|
#cfg(all(target="native", not(platform="windows")))
/// Loads an immutable snapshot of the system-configured local timezone.
/// Each call reads fresh OS data; retain the returned zone to reuse its rules.
/// Linux and macOS load `/etc/localtime`, independently of the process's `TZ`
/// environment variable. Windows loads the current zone's annual rules and
/// respects the system's daylight-saving setting. Requires the native backend.
/// The zone ID is a source label and is not necessarily an IANA identifier.
/// OS failures raise `LocalZoneError`, preserving the system error code and message.
/// Malformed or unsupported timezone data also raises an error.
pub fn local_zone() -> Zone raise Error {
  let error = Ref(0U)
  let path = local_zone_path(b"/etc/localtime", error)
  guard error.val == 0U else {
    raise local_zone_error(error.val, "resolve /etc/localtime")
  }
  let data = read_zone_file(path, error)
  guard error.val == 0U else {
    raise local_zone_error(
      error.val,
      "read timezone file \{@utf8.decode_lossy(path)}",
    )
  }
  // Derive the label from the same resolved path whose contents were read.
  let id = match @utf8.decode_lossy(path).split_once("/zoneinfo/") {
    Some((_, name)) if !name.is_empty() => name.to_owned()
    _ => "local"
  }
  Zone::from_tzif(id, data)
}

///|
#cfg(all(target="native", platform="windows"))
// One captured DYNAMIC_TIME_ZONE_INFORMATION, owned by the MoonBit runtime.
priv type WindowsTimezone

///|
#cfg(all(target="native", platform="windows"))
#borrow(record, error)
extern "C" fn WindowsTimezone::load(
  record : FixedArray[Byte],
  error : Ref[UInt],
) -> WindowsTimezone = "moonbitlang_x_time_windows_current_zone"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::name(self : WindowsTimezone) -> String = "moonbitlang_x_time_windows_zone_name"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self, years)
extern "C" fn WindowsTimezone::effective_years(
  self : WindowsTimezone,
  years : FixedArray[UInt],
) -> UInt = "moonbitlang_x_time_windows_zone_years"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self, record)
extern "C" fn WindowsTimezone::rule_for_year(
  self : WindowsTimezone,
  year : Int,
  record : FixedArray[Byte],
) -> UInt = "moonbitlang_x_time_windows_zone_rule"

///|
#cfg(all(target="native", platform="windows"))
/// Loads an immutable snapshot of the system-configured local timezone.
/// Each call reads fresh OS data; retain the returned zone to reuse its rules.
/// Linux and macOS load `/etc/localtime`, independently of the process's `TZ`
/// environment variable. Windows loads the current zone's annual rules and
/// respects the system's daylight-saving setting. Requires the native backend.
/// The zone ID is a source label and is not necessarily an IANA identifier.
/// OS failures raise `LocalZoneError`, preserving the system error code and message.
/// Malformed or unsupported timezone data also raises an error.
pub fn local_zone() -> Zone raise Error {
  // Native marshalling supplies a 44-byte REG_TZI_FORMAT record, followed by
  // DynamicDaylightTimeDisabled. The key name is a NUL-padded UTF-16 string.
  let current = FixedArray::make(45, b'\x00')
  let error = Ref(0U)
  let windows = WindowsTimezone::load(current, error)
  guard error.val == 0U else {
    raise local_zone_error(error.val, "GetDynamicTimeZoneInformation")
  }
  let name = windows.name()
  let name = match name.split_once("\u0000") {
    Some((name, _)) => name.to_owned()
    None => name
  }
  let id = if name.is_empty() { "local" } else { name }
  let data = if current[44] != b'\x00' || name.is_empty() {
    // Disabling dynamic DST keeps the current rule; its transition dates
    // determine whether DST itself is disabled. Zero bounds mean one rule.
    Bytes::make(8, b'\x00') + Bytes::from_array(current[:44])
  } else {
    let years : FixedArray[UInt] = [0U, 0U]
    let error = windows.effective_years(years)
    if error == 2U { // ERROR_FILE_NOT_FOUND: no historical year range.
      Bytes::make(8, b'\x00') + Bytes::from_array(current[:44])
    } else {
      guard error == 0U else {
        raise local_zone_error(
          error,
          "read Windows timezone year range for \{id}",
        )
      }
      let first = years[0]
      let last = years[1]
      guard first >= 1U && first <= last && last <= 65535U else {
        fail("Invalid Windows timezone year range")
      }
      let data : Array[Byte] = Array(
        capacity=8 + (last - first + 1U).reinterpret_as_int() * 44,
      )
      // The private snapshot starts with two little-endian u32 year bounds.
      for year in years {
        for shift in [0, 8, 16, 24] {
          data.push((year >> shift).to_byte())
        }
      }
      let record = FixedArray::make(44, b'\x00')
      for year in first..<=last {
        let error = windows.rule_for_year(year.reinterpret_as_int(), record)
        guard error == 0U else {
          raise local_zone_error(
            error,
            "GetTimeZoneInformationForYear(\{year}, \{id})",
          )
        }
        data.append(record[:])
      }
      Bytes::from_array(data)
    }
  }
  Zone::from_windows_data(id, data)
}

///|
#cfg(all(target="native", platform="windows"))
extern "C" fn local_zone_error_message(code : UInt) -> String = "moonbitlang_x_time_local_zone_error_message"

///|
#cfg(all(target="native", not(platform="windows")))
extern "C" fn local_zone_error_message(code : UInt) -> Bytes = "moonbitlang_x_time_local_zone_error_message"

///|
#cfg(all(target="native", platform="windows"))
fn local_zone_error(code : UInt, context : String) -> LocalZoneError {
  let message = local_zone_error_message(code).trim_end(chars="\r\n").to_owned()
  LocalZoneError(code, context~, message~)
}

///|
#cfg(all(target="native", not(platform="windows")))
fn local_zone_error(code : UInt, context : String) -> LocalZoneError {
  let message = @utf8.decode_lossy(local_zone_error_message(code))
  LocalZoneError(code, context~, message~)
}

///|
#cfg(all(target="native", platform="windows"))
// Imports cannot yet be conditional; UTF-8 decoding is used by Unix readers.
let _unused_native_utf8_import : Unit = ignore(@utf8.decode_lossy(b""))

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
extern "C" fn local_zone_path(path : Bytes, error : Ref[UInt32]) -> Bytes = "moonbitlang_x_time_local_zone_path"

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(path, error)
extern "C" fn read_zone_file(path : Bytes, error : Ref[UInt32]) -> Bytes = "moonbitlang_x_time_read_zone_file"

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
// Captured native zone and working annual result, owned by the MoonBit runtime.
priv type WindowsTimezone

///|
#cfg(all(target="native", platform="windows"))
#borrow(error)
extern "C" fn WindowsTimezone::load(error : Ref[UInt32]) -> WindowsTimezone = "moonbitlang_x_time_windows_current_zone"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::name(self : WindowsTimezone) -> String = "moonbitlang_x_time_windows_zone_name"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self, years)
extern "C" fn WindowsTimezone::effective_years(
  self : WindowsTimezone,
  years : FixedArray[UInt32],
) -> UInt32 = "moonbitlang_x_time_windows_zone_years"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::rule_for_year(
  self : WindowsTimezone,
  year : Int32,
) -> UInt32 = "moonbitlang_x_time_windows_zone_rule"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::dynamic_disabled(self : WindowsTimezone) -> Bool = "moonbitlang_x_time_windows_dynamic_disabled"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::bias(self : WindowsTimezone) -> Int32 = "moonbitlang_x_time_windows_bias"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::standard_bias(self : WindowsTimezone) -> Int32 = "moonbitlang_x_time_windows_standard_bias"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::daylight_bias(self : WindowsTimezone) -> Int32 = "moonbitlang_x_time_windows_daylight_bias"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_year(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_year"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_month(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_month"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_weekday(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_weekday"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_day(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_day"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_hour(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_hour"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_minute(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_minute"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_second(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_second"

///|
#cfg(all(target="native", platform="windows"))
#borrow(self)
extern "C" fn WindowsTimezone::date_millisecond(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> Int32 = "moonbitlang_x_time_windows_date_millisecond"

///|
#cfg(all(target="native", platform="windows"))
fn WindowsTimezone::read_date(
  self : WindowsTimezone,
  daylight~ : Bool,
) -> WindowsSystemTime {
  {
    year: self.date_year(daylight~),
    month: self.date_month(daylight~),
    weekday: self.date_weekday(daylight~),
    day: self.date_day(daylight~),
    hour: self.date_hour(daylight~),
    minute: self.date_minute(daylight~),
    second: self.date_second(daylight~),
    millisecond: self.date_millisecond(daylight~),
  }
}

///|
#cfg(all(target="native", platform="windows"))
fn WindowsTimezone::read_rule(self : WindowsTimezone) -> WindowsTimeZoneInfo {
  {
    bias: self.bias(),
    standard_bias: self.standard_bias(),
    daylight_bias: self.daylight_bias(),
    standard_date: self.read_date(daylight=false),
    daylight_date: self.read_date(daylight=true),
  }
}

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
  let error = Ref(0U)
  let windows = WindowsTimezone::load(error)
  guard error.val == 0U else {
    raise local_zone_error(error.val, "GetDynamicTimeZoneInformation")
  }
  let name = windows.name()
  let name = match name.split_once("\u0000") {
    Some((name, _)) => name.to_owned()
    None => name
  }
  let id = if name.is_empty() { "local" } else { name }
  let (first_year, rules) = if windows.dynamic_disabled() || name.is_empty() {
    // Disabling dynamic DST keeps the current rule; its transition dates
    // determine whether DST itself is disabled.
    (None, [windows.read_rule()])
  } else {
    let years : FixedArray[UInt32] = [0U, 0U]
    let error = windows.effective_years(years)
    if error == 2U { // ERROR_FILE_NOT_FOUND: no historical year range.
      (None, [windows.read_rule()])
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
      let rules = Array(capacity=(last - first + 1U).reinterpret_as_int())
      for year in first..<=last {
        let error = windows.rule_for_year(year.reinterpret_as_int())
        guard error == 0U else {
          raise local_zone_error(
            error,
            "GetTimeZoneInformationForYear(\{year}, \{id})",
          )
        }
        // Copy fields into immutable MoonBit values before fetching another year.
        rules.push(windows.read_rule())
      }
      (Some(first.reinterpret_as_int()), rules)
    }
  }
  Zone::from_windows_rules(id, first_year, rules)
}

///|
#cfg(all(target="native", platform="windows"))
extern "C" fn local_zone_error_message(code : UInt32) -> String = "moonbitlang_x_time_local_zone_error_message"

///|
#cfg(all(target="native", not(platform="windows")))
extern "C" fn local_zone_error_message(code : UInt32) -> Bytes = "moonbitlang_x_time_local_zone_error_message"

///|
#cfg(all(target="native", platform="windows"))
fn local_zone_error(code : UInt32, context : String) -> LocalZoneError {
  let message = local_zone_error_message(code).trim_end(chars="\r\n").to_owned()
  LocalZoneError(code, context~, message~)
}

///|
#cfg(all(target="native", not(platform="windows")))
fn local_zone_error(code : UInt32, context : String) -> LocalZoneError {
  let message = @utf8.decode_lossy(local_zone_error_message(code))
  LocalZoneError(code, context~, message~)
}

///|
#cfg(all(target="native", platform="windows"))
// Imports cannot yet be conditional; UTF-8 decoding is used by Unix readers.
let _unused_native_utf8_import : Unit = ignore(@utf8.decode_lossy(b""))

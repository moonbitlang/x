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
#unsafe_skip_stub_check
#borrow(handle)
fn capture_zone(handle : FixedArray[UInt64]) -> UInt32 = "moonbitlang/core" "time/windows/get_dynamic_time_zone_information"

///|
#unsafe_skip_stub_check
#borrow(output)
fn zone_metadata(handle : UInt64, output : Bytes, capacity : Int32) -> UInt32 = "moonbitlang/core" "time/windows/get_time_zone_metadata"

///|
#unsafe_skip_stub_check
#borrow(output)
fn current_rule_raw(handle : UInt64, output : Bytes) -> UInt32 = "moonbitlang/core" "time/windows/get_current_time_zone_rule"

///|
#unsafe_skip_stub_check
#borrow(years)
fn effective_years(handle : UInt64, years : FixedArray[UInt32]) -> UInt32 = "moonbitlang/core" "time/windows/get_dynamic_time_zone_information_effective_years"

///|
#unsafe_skip_stub_check
#borrow(rule)
fn rule_for_year(handle : UInt64, year : Int32, rule : Bytes) -> UInt32 = "moonbitlang/core" "time/windows/get_time_zone_information_for_year"

///|
#unsafe_skip_stub_check
fn release_zone(handle : UInt64) -> UInt32 = "moonbitlang/core" "time/windows/free_time_zone"

///|
// Two u32 header fields followed by at most 128 UTF-16LE code units.
const MAX_METADATA_BYTES : Int32 = 264

///|
const RULE_BYTES : Int32 = 44

///|
priv struct WindowsTimezone {
  handle : UInt64
  rule : Bytes
}

///|
fn WindowsTimezone::effective_years(
  self : WindowsTimezone,
  years : FixedArray[UInt32],
) -> UInt32 {
  effective_years(self.handle, years)
}

///|
fn WindowsTimezone::rule_for_year(
  self : WindowsTimezone,
  year : Int32,
) -> UInt32 {
  rule_for_year(self.handle, year, self.rule)
}

///|
fn WindowsTimezone::current_rule(
  self : WindowsTimezone,
) -> WindowsTimeZoneInfo raise Error {
  let code = current_rule_raw(self.handle, self.rule)
  guard code == 0U else {
    raise local_zone_error(code, "read current Windows timezone rule")
  }
  self.read_rule()
}

///|
fn read_metadata(handle : UInt64) -> (String, Bool) raise Error {
  let out = Bytes::make(MAX_METADATA_BYTES, 0)
  let code = zone_metadata(handle, out, out.length())
  guard code == 0U else {
    raise local_zone_error(code, "read Windows timezone metadata")
  }
  decode_metadata(out)
}

///|
fn decode_metadata(out : Bytes) -> (String, Bool) raise Error {
  guard out[:] is [u32le(disabled), u32le(len), .. bytes] &&
    len <= bytes.length().reinterpret_as_uint() &&
    len % 2U == 0U else {
    fail("invalid Windows timezone metadata")
  }
  // Preserve native UTF-16 code units, including unpaired surrogates. On linear
  // Wasm String uses the same little-endian representation; the bounds and
  // even byte count above make this an exact copy without constructing Char.
  let name = out.to_unchecked_string(offset=8, length=len.reinterpret_as_int())
  (name, disabled != 0U)
}

///|
fn decode_system_time(bytes : BytesView) -> WindowsSystemTime {
  guard bytes
    is [
      u16le(year),
      u16le(month),
      u16le(weekday),
      u16le(day),
      u16le(hour),
      u16le(minute),
      u16le(second),
      u16le(millisecond),
    ] else {
    abort("invalid SYSTEMTIME size")
  }
  {
    year: year.reinterpret_as_int(),
    month: month.reinterpret_as_int(),
    weekday: weekday.reinterpret_as_int(),
    day: day.reinterpret_as_int(),
    hour: hour.reinterpret_as_int(),
    minute: minute.reinterpret_as_int(),
    second: second.reinterpret_as_int(),
    millisecond: millisecond.reinterpret_as_int(),
  }
}

///|
fn WindowsTimezone::read_rule(self : WindowsTimezone) -> WindowsTimeZoneInfo {
  guard self.rule
    is [i32le(bias), i32le(standard_bias), i32le(daylight_bias), .. dates] else {
    abort("invalid timezone rule size")
  }
  {
    bias,
    standard_bias,
    daylight_bias,
    standard_date: decode_system_time(dates[:16]),
    daylight_date: decode_system_time(dates[16:]),
  }
}

///|
fn local_zone_error(code : UInt32, context : String) -> LocalZoneError {
  LocalZoneError(
    code,
    context~,
    message=@wasm_file.error_message(code.reinterpret_as_int()),
  )
}

///|
/// Load the configured system zone using Moonrun's linear Wasm filesystem or
/// Windows timezone imports. The resulting Zone owns all its rule data.
pub fn local_zone() -> Zone raise Error {
  if @wasm_file.is_windows() {
    let slot : FixedArray[UInt64] = [0UL]
    let code = capture_zone(slot)
    guard code == 0U else {
      raise local_zone_error(code, "GetDynamicTimeZoneInformation")
    }
    let handle = slot[0]
    defer ignore(release_zone(handle))
    let (name, disabled) = read_metadata(handle)
    let windows : WindowsTimezone = {
      handle,
      rule: Bytes::make(RULE_BYTES, 0),
    }
    windows.to_zone(name, disabled)
  } else {
    try {
      let raw = @wasm_file.realpath_bytes("/etc/localtime")
      // The filesystem imports accept Unicode paths. For an unrepresentable
      // target, read the original native link and use its neutral source label.
      let path = @utf8.decode(raw, ignore_bom=false) catch {
        _ => "/etc/localtime"
      }
      let data = @wasm_file.read_file(path)
      let id = match path.split_once("/zoneinfo/") {
        Some((_, name)) if !name.is_empty() => name.to_owned()
        _ => "local"
      }
      Zone::from_tzif(id, data)
    } catch {
      @wasm_file.Os(code, context) =>
        raise local_zone_error(code.reinterpret_as_uint(), context)
      error => raise error
    }
  }
}

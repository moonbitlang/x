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
test "system local zone loads as a reusable snapshot" {
  let zone = local_zone()
  assert_false(zone.id.is_empty())
  for second in [-2208988800L, 0L, 1711846800L, 1730613600L, 2208988800L] {
    let value = ZonedDateTime::from_unix_second(second, nanosecond=123, zone~)
    assert_eq(value.to_unix_second(), second)
    assert_eq(value.nanosecond(), 123)
    let local_value = ZonedDateTime::from_plain(value.datetime, zone~)
    // An overlap can select another occurrence, but preserves the reading.
    assert_eq(local_value.datetime, value.datetime)
  }
}

///|
#cfg(platform="windows")
extern "C" fn windows_local_offset(second : Int64, local_year : Int) -> Int = "moonbitlang_x_time_windows_local_offset"

///|
#cfg(platform="windows")
test "Windows local snapshot agrees with native conversion" {
  let zone = local_zone()
  for year in [1900, 1970, 2006, 2007, 2011, 2014, 2015, 2018, 2024, 2040] {
    for month in 1..<=12 {
      let second = PlainDateTime::of(year, month, 15, hour=12).to_unix_second()
      assert_eq(
        zone.lookup_offset(second).seconds(),
        windows_local_offset(second, year),
      )
    }
  }
  for (transition, _) in zone.transitions {
    if transition < -11644473600L || transition > 253402300798L {
      continue
    }
    for second in [transition - 1, transition, transition + 1] {
      let local_year = ZonedDateTime::from_unix_second(second, zone~).year()
      assert_eq(
        zone.lookup_offset(second).seconds(),
        windows_local_offset(second, local_year),
      )
    }
  }
}

///|
#cfg(not(platform="windows"))
test "native timezone file reads report failure without retaining file data" {
  let error = Ref(123U)
  let data = read_zone_file(b"time/testdata/Asia/Pyongyang.tzif", error)
  assert_eq(error.val, 0U)
  assert_eq(data, pyongyang_tzif)
  let missing = read_zone_file(b"time/testdata/no-such-zone.tzif", error)
  assert_eq(error.val, 2U) // ENOENT on Linux and macOS.
  assert_true(missing.is_empty())
}

///|
#cfg(not(platform="windows"))
test "native timezone reads preserve the OS error instead of replacing it with EIO" {
  let error = Ref(0U)
  let data = read_zone_file(b"time/testdata", error)
  // macOS reaches the read and returns EISDIR (21). Linux can reject the seek
  // with EINVAL (22), or report a directory hash offset beyond our size limit
  // (EFBIG, 27). None of these should be collapsed to generic EIO (5).
  match error.val {
    21U | 22U | 27U => ()
    code => fail("Unexpected directory error: \{code}")
  }
  assert_true(data.is_empty())
}

///|
#cfg(not(platform="windows"))
test "timezone path resolution preserves errors" {
  let error = Ref(0U)
  let path = local_zone_path(b"time/testdata/no-such-zone.tzif", error)
  assert_eq(error.val, 2U) // ENOENT on Linux and macOS.
  assert_true(path.is_empty())
  let reported = local_zone_error(error.val, "resolve timezone path")
  let LocalZoneError(code, context~, message~) = reported
  assert_eq(code, error.val)
  assert_eq(context, "resolve timezone path")
  assert_false(message.is_empty())
  let path = local_zone_path(b"time/testdata/Asia/Pyongyang.tzif", error)
  assert_eq(error.val, 0U)
  assert_false(path.is_empty())
}

///|
test "unavailable error descriptions retain the original code and context" {
  let LocalZoneError(code, context~, ..) = local_zone_error(
    4294967295U, "load timezone",
  )
  assert_eq(code, 4294967295U)
  assert_eq(context, "load timezone")
}

///|
#cfg(platform="windows")
#borrow(self, years)
extern "C" fn WindowsTimezone::registry_years(
  self : WindowsTimezone,
  years : FixedArray[UInt],
) -> UInt = "moonbitlang_x_time_windows_registry_years"

///|
#cfg(platform="windows")
test "Windows 7 registry year range agrees with runtime API discovery" {
  let error = Ref(0U)
  let windows = WindowsTimezone::load(FixedArray::make(45, b'\x00'), error)
  assert_eq(error.val, 0U)
  let years : FixedArray[UInt] = [0U, 0U]
  let registry_years : FixedArray[UInt] = [0U, 0U]
  let status = windows.effective_years(years)
  assert_eq(windows.registry_years(registry_years), status)
  assert_true(status == 0U || status == 2U)
  if status == 0U {
    assert_eq(years, registry_years)
  } else {
    let LocalZoneError(code, context~, message~) = local_zone_error(
      status, "read year range",
    )
    assert_eq(code, status)
    assert_eq(context, "read year range")
    assert_false(message.is_empty())
  }
}

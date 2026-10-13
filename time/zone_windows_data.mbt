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
// Values copied through FFI accessors. These types describe Windows fields,
// without depending on the C struct's layout or introducing a binary format.
// Constructed only by Windows-native code and white-box tests.
#warnings("-struct_never_constructed")
priv struct WindowsSystemTime {
  year : Int32
  month : Int32
  weekday : Int32
  day : Int32
  hour : Int32
  minute : Int32
  second : Int32
  millisecond : Int32
} derive(Eq)

///|
#warnings("-struct_never_constructed")
priv struct WindowsTimeZoneInfo {
  bias : Int32
  standard_bias : Int32
  daylight_bias : Int32
  standard_date : WindowsSystemTime
  daylight_date : WindowsSystemTime
}

///|
// Temporary normalized records. Only Zone's transition table and Recurring
// endpoints survive construction; there is no Windows-specific lookup path.
priv enum WindowsRecord {
  Fixed(ZoneOffset)
  Annual(WindowsRule)
  Absolute(Int32, WindowsRule)
}

///|
fn WindowsRecord::for_year(self : WindowsRecord, year : Int32) -> Recurring {
  match self {
    Fixed(offset) => Fixed(offset)
    Annual(rule) => Windows(rule)
    Absolute(only_year, rule) =>
      if year == only_year {
        Windows(rule)
      } else {
        Fixed(rule.standard)
      }
  }
}

///|
fn WindowsSystemTime::to_transition(
  self : WindowsSystemTime,
) -> (Int32, WindowsDate?) raise Error {
  let { year, month, weekday, day, hour, minute, second, millisecond, } = self
  if month == 0 {
    return (0, None)
  }
  guard year >= 0 &&
    year <= 65535 &&
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    (if year == 0 {
      weekday >= 0 && weekday <= 6 && day <= 5
    } else {
      day <= 31
    }) &&
    hour >= 0 &&
    hour < 24 &&
    minute >= 0 &&
    minute < 60 &&
    second >= 0 &&
    second < 60 &&
    (
      millisecond == 0 ||
      (hour == 23 && minute == 59 && second == 59 && millisecond == 999)
    ) else {
    fail("Invalid or subsecond Windows transition date")
  }
  guard year == 0 || day <= calc_days_in_month(year, month) else {
    fail("Invalid Windows transition day")
  }
  // Windows's end-of-day convention denotes the following midnight.
  // See testdata/windows/README.md for the native contract and provenance.
  let second = if millisecond == 999 {
    86400
  } else {
    hour * 3600 + minute * 60 + second
  }
  let date = if year == 0 && month == 1 && day == 1 && second == 0 {
    WindowsDate::YearBoundary
  } else if year == 0 {
    MonthWeekDay(month~, week=day, weekday~, second~)
  } else {
    // Express this date in the annual evaluator only for its original year.
    // WindowsRecord::Absolute prevents it from recurring in any other year.
    let fixed = date_to_fixed_days(year, month, day)
    let weekday = (((fixed + 6L) % 7L + 7L) % 7L).to_int()
    MonthWeekDay(month~, week=(day - 1) / 7 + 1, weekday~, second~)
  }
  (year, Some(date))
}

///|
// A missing first year denotes a single current rule. Otherwise, the array
// contains consecutive annual rules starting at first_year. Only the native
// Windows loader calls this outside white-box tests.
#warnings("-unused_value")
fn Zone::from_windows_rules(
  id : String,
  first_year : Int32?,
  rules : Array[WindowsTimeZoneInfo],
) -> Zone raise Error {
  let first = match first_year {
    None => {
      guard rules.length() == 1 else {
        fail("Expected one current Windows timezone rule")
      }
      0
    }
    Some(first) => {
      guard first >= 1 &&
        first <= 65535 &&
        !rules.is_empty() &&
        rules.length() <= 65536 - first else {
        fail("Invalid Windows timezone year range")
      }
      first
    }
  }
  let last = first + rules.length() - 1
  let records : Array[WindowsRecord] = []
  for info in rules {
    let (end_year, end) = info.standard_date.to_transition()
    let (start_year, start) = info.daylight_date.to_transition()
    guard (start is None) == (end is None) && start_year == end_year else {
      fail("Incomplete or inconsistent Windows transition dates")
    }
    // With no seasonal dates Windows ignores both seasonal biases.
    let standard_bias = if start is None { 0 } else { info.standard_bias }
    let daylight_bias = if start is None { 0 } else { info.daylight_bias }
    let offsets = [standard_bias, daylight_bias].mapi((i, seasonal_bias) => {
      let seconds = -(info.bias.to_int64() + seasonal_bias.to_int64()) * 60L
      guard seconds >= -64800L && seconds <= 64800L else {
        fail("Windows timezone offset exceeds 18 hours")
      }
      let offset = ZoneOffset::from_seconds(seconds.to_int())
      {
        ..offset,
        abbrev: if seconds == 0L {
          "+00"
        } else {
          offset.id()
        },
        dst: i == 1,
      }
    })
    // Identical native dates disable DST. Compare before normalization:
    // distinct January markers can both become YearBoundary.
    match (start, end) {
      (Some(start), Some(end)) if info.standard_date != info.daylight_date => {
        let rule : WindowsRule = {
          standard: offsets[0],
          daylight: offsets[1],
          start,
          end,
        }
        records.push(
          if start_year == 0 {
            Annual(rule)
          } else {
            Absolute(start_year, rule)
          },
        )
      }
      _ => records.push(Fixed(offsets[0]))
    }
  }
  let endpoints = [records[0], records.last().unwrap()].map(record => {
    match record {
      Fixed(offset) => Recurring::Fixed(offset)
      Annual(rule) => Windows(rule)
      Absolute(_, rule) => Fixed(rule.standard)
    }
  })
  if records.length() == 1 && !(records[0] is Absolute(_, _)) {
    let rule = endpoints[0]
    return {
      id,
      offsets: rule.offsets(),
      transitions: [],
      past: None,
      future: if rule is Fixed(_) {
        None
      } else {
        Some((@int64.MIN_VALUE, rule))
      },
    }
  }
  let table_first = first
  let table_last = last
  // Absolute endpoint dates remain one-off events even outside the registry's
  // year bounds. Expand only the finite span containing those dates.
  let first = match records[0] {
    Absolute(year, _) =>
      if table_first == 0 {
        year
      } else {
        table_first.min(year)
      }
    _ => table_first
  }
  let last = match records.last().unwrap() {
    Absolute(year, _) => table_last.max(year)
    _ => table_last
  }
  let before = records[0].for_year(first - 1)
  let mut previous = match before {
    Windows(rule) => rule.ending_offset(first - 1)
    _ => before.lookup_offset(0L)
  }
  let cutoff = (date_to_fixed_days(first, 1, 1) - days_zero_year_to_unix_epoch) *
    86400L -
    previous.seconds().to_int64()
  let offsets : Array[ZoneOffset] = []
  let indices : Map[(Int32, Bool), Int32] = Map([])
  let transitions : Array[(Int64, Int32)] = []
  let mut finish = cutoff
  for year in first..<=last {
    let index = (year - table_first).clamp(min=0, max=records.length() - 1)
    let rule = records[index].for_year(year)
    let begin = finish
    let ending = match rule {
      Windows(rule) => rule.ending_offset(year)
      _ => rule.lookup_offset(0L)
    }
    finish = (date_to_fixed_days(year + 1, 1, 1) - days_zero_year_to_unix_epoch) *
      86400L -
      ending.seconds().to_int64()
    let changes = [begin]
    if rule is Windows(windows) {
      if windows.start != YearBoundary {
        changes.push(windows.start.time(year, windows.standard.seconds()))
      }
      if windows.end != YearBoundary {
        changes.push(windows.end.time(year, windows.daylight.seconds()))
      }
    }
    changes.sort()
    for time in changes {
      if time < begin || time >= finish {
        continue
      }
      let offset = match rule {
        Windows(rule) => rule.offset_in_year(year, time)
        _ => rule.lookup_offset(time)
      }
      let key = (offset.seconds(), offset.is_dst())
      let index = match indices.get(key) {
        Some(index) => index
        None => {
          let index = offsets.length()
          offsets.push(offset)
          indices[key] = index
          index
        }
      }
      if transitions.is_empty() ||
        offset.seconds() != previous.seconds() ||
        offset.is_dst() != previous.is_dst() {
        transitions.push((time, index))
      }
      previous = offset
    }
  }
  {
    id,
    offsets,
    transitions,
    past: Some((cutoff, endpoints[0])),
    future: Some((finish, endpoints[1])),
  }
}

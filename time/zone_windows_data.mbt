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
// Temporary decoded records. Only Zone's transition table and Recurring
// endpoints survive construction; there is no Windows-specific lookup path.
priv enum WindowsRecord {
  Fixed(ZoneOffset)
  Annual(WindowsRule)
  Absolute(Int, WindowsRule)
}

///|
fn WindowsRecord::for_year(self : WindowsRecord, year : Int) -> Recurring {
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
fn read_windows_date(
  bytes : BytesView,
) -> (Int, WindowsDate?, BytesView) raise Error {
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
      .. rest,
    ] else {
    fail("Truncated Windows transition date")
  }
  if month == 0U {
    return (0, None, rest)
  }
  guard month <= 12U &&
    day > 0U &&
    (if year == 0U { weekday <= 6U && day <= 5U } else { day <= 31U }) &&
    hour < 24U &&
    minute < 60U &&
    second < 60U &&
    (
      millisecond == 0U ||
      (hour == 23U && minute == 59U && second == 59U && millisecond == 999U)
    ) else {
    fail("Invalid or subsecond Windows transition date")
  }
  let year = year.reinterpret_as_int()
  let month = month.reinterpret_as_int()
  let day = day.reinterpret_as_int()
  guard year == 0 || day <= calc_days_in_month(year, month) else {
    fail("Invalid Windows transition day")
  }
  // Windows's end-of-day convention denotes the following midnight.
  // See testdata/windows/README.md for the native contract and provenance.
  let second = if millisecond == 999U {
    86400
  } else {
    (hour * 3600U + minute * 60U + second).reinterpret_as_int()
  }
  let date = if year == 0 && month == 1 && day == 1 && second == 0 {
    WindowsDate::YearBoundary
  } else if year == 0 {
    MonthWeekDay(
      month~,
      week=day,
      weekday=weekday.reinterpret_as_int(),
      second~,
    )
  } else {
    // Express this date in the annual evaluator only for its original year.
    // WindowsRecord::Absolute prevents it from recurring in any other year.
    let fixed = date_to_fixed_days(year, month, day)
    let weekday = (((fixed + 6L) % 7L + 7L) % 7L).to_int()
    MonthWeekDay(month~, week=(day - 1) / 7 + 1, weekday~, second~)
  }
  (year, Some(date), rest)
}

///|
// The native reader supplies two little-endian u32 year bounds, followed by
// 44-byte records in REG_TZI_FORMAT layout. Zero bounds mean one current rule.
// Only the native Windows entry point calls this outside white-box tests.
#warnings("-unused_value")
fn Zone::from_windows_data(id : String, data : BytesView) -> Zone raise Error {
  guard data is [u32le(first), u32le(last), .. rest] else {
    fail("Truncated Windows timezone snapshot")
  }
  guard first <= last &&
    last <= 65535U &&
    (first > 0U || last == 0U) &&
    rest.length().to_uint64() ==
    (last.to_uint64() - first.to_uint64() + 1UL) * 44UL else {
    fail("Invalid Windows timezone year range")
  }
  let records : Array[WindowsRecord] = []
  for rest = rest; !rest.is_empty(); {
    guard rest
      is [i32le(bias), i32le(standard_bias), i32le(daylight_bias), .. rest] else {
      fail("Truncated Windows timezone rule")
    }
    let (end_year, end, rest) = read_windows_date(rest)
    let (start_year, start, rest) = read_windows_date(rest)
    guard (start is None) == (end is None) && start_year == end_year else {
      fail("Incomplete or inconsistent Windows transition dates")
    }
    // With no seasonal dates Windows ignores both seasonal biases.
    let standard_bias = if start is None { 0 } else { standard_bias }
    let daylight_bias = if start is None { 0 } else { daylight_bias }
    let offsets = [standard_bias, daylight_bias].mapi((i, seasonal_bias) => {
      let seconds = -(bias.to_int64() + seasonal_bias.to_int64()) * 60L
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
    match (start, end) {
      (Some(start), Some(end)) => {
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
    continue rest
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
  let table_first = first.reinterpret_as_int()
  let table_last = last.reinterpret_as_int()
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
  let indices : Map[(Int, Bool), Int] = Map([])
  let transitions : Array[(Int64, Int)] = []
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

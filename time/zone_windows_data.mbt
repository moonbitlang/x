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
}

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
  // A finite timeline after expanding each date independently. Repeated
  // events that merely reassert the active offset have already been removed.
  Dated(ZoneOffset, Array[(Int64, ZoneOffset)])
}

///|
priv enum WindowsTransition {
  Annual(WindowsDate)
  // Local wall-clock seconds, including the actual year and day of month.
  Once(Int64)
} derive(Eq)

///|
fn WindowsRecord::lookup_offset(
  self : WindowsRecord,
  year : Int32,
  second : Int64,
) -> ZoneOffset {
  match self {
    Fixed(offset) => offset
    Annual(rule) => rule.offset_in_year(year, second)
    Dated(initial, changes) => {
      let mut offset = initial
      for (time, next) in changes {
        if time > second {
          break
        }
        offset = next
      }
      offset
    }
  }
}

///|
fn WindowsRecord::year_boundary(self : WindowsRecord, year : Int32) -> Int64 {
  let wall = (date_to_fixed_days(year, 1, 1) - days_zero_year_to_unix_epoch) *
    86400L
  match self {
    Fixed(offset) => wall - offset.seconds().to_int64()
    Annual(rule) => rule.year_boundary(year)
    Dated(initial, changes) => {
      // A midnight overlap belongs to the preceding year's history until its
      // last occurrence. If midnight is skipped, the new year starts at the
      // actual clock change, not at a fabricated instant within the gap.
      let mut boundary : Int64? = None
      let mut gap : Int64? = None
      let mut start = @int64.MIN_VALUE
      let mut offset = initial
      for (time, next) in changes {
        let candidate = wall - offset.seconds().to_int64()
        if candidate >= start && candidate < time {
          boundary = Some(candidate)
        }
        if wall >= time + offset.seconds().to_int64() &&
          wall < time + next.seconds().to_int64() {
          gap = Some(time)
        }
        start = time
        offset = next
      }
      let candidate = wall - offset.seconds().to_int64()
      if candidate >= start {
        boundary = Some(candidate)
      }
      // Finite offset intervals cover every instant; a wall midnight either
      // occurs in an interval or lies inside a forward jump between them.
      match boundary {
        Some(time) => time
        None => gap.unwrap()
      }
    }
  }
}

///|
fn WindowsSystemTime::to_transition(
  self : WindowsSystemTime,
) -> WindowsTransition? raise Error {
  let { year, month, weekday, day, hour, minute, second, millisecond, } = self
  if month == 0 {
    return None
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
  let date = if year != 0 {
    // Absolute dates never pass through the week/weekday evaluator. Adding
    // 86400 naturally carries an end-of-day occurrence into the next year.
    Once(
      (date_to_fixed_days(year, month, day) - days_zero_year_to_unix_epoch) *
      86400L +
      second.to_int64(),
    )
  } else {
    Annual(MonthWeekDay(month~, week=day, weekday~, second~))
  }
  Some(date)
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
    let end = info.standard_date.to_transition()
    let start = info.daylight_date.to_transition()
    guard (start is None) == (end is None) else {
      fail("Incomplete Windows transition dates")
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
    // Equal dates disable DST; absolute dates ignore the weekday field.
    // Compare before distinct January dates can become YearBoundary.
    match (start, end) {
      (Some(start), Some(end)) if start != end => {
        if start is Annual(start) && end is Annual(end) {
          // Preserve the established annual-rule boundary convention. Mixed
          // pairs keep the literal relative dates from TIME_ZONE_INFORMATION.
          let start = match start {
            MonthWeekDay(month=1, week=1, second=0, ..) => YearBoundary
            _ => start
          }
          let end = match end {
            MonthWeekDay(month=1, week=1, second=0, ..) => YearBoundary
            _ => end
          }
          records.push(
            Annual({ standard: offsets[0], daylight: offsets[1], start, end, }),
          )
          continue
        }
        // At least one date is one-time. A mixed pair settles to the yearly
        // event's offset after that event next occurs. Thus only neighboring
        // years around the dated event are needed, not an arbitrary horizon.
        let years = [start, end].filter_map(date => {
          match date {
            Once(wall) =>
              Some(
                fixed_days_to_year_ord(
                  wall / 86400L + days_zero_year_to_unix_epoch,
                ).0,
              )
            Annual(_) => None
          }
        })
        let candidates : Array[(Int64, Int32)] = []
        // Tag 0 enters daylight, tag 1 enters standard. Sorting the tag also
        // makes standard win when two events coincide, as for equal dates.
        for tag, date in [start, end] {
          let before = offsets[tag].seconds()
          match date {
            Once(wall) => candidates.push((wall - before.to_int64(), tag))
            Annual(date) => {
              let year = years[0] // The other member is the sole one-time date.
              for year in (year - 1)..<=(year + 1) {
                candidates.push((date.time(year, before), tag))
              }
            }
          }
        }
        candidates.sort()
        let initial = match (start, end) {
          (Annual(_), _) => offsets[1]
          (_, Annual(_)) => offsets[0]
          _ => offsets[candidates[0].1] // Before the earliest one-time event.
        }
        let changes : Array[(Int64, ZoneOffset)] = []
        let mut previous = initial
        for i, (time, tag) in candidates {
          if i + 1 < candidates.length() && candidates[i + 1].0 == time {
            continue
          }
          let next = offsets[1 - tag]
          if next.seconds() != previous.seconds() ||
            next.is_dst() != previous.is_dst() {
            changes.push((time, next))
            previous = next
          }
        }
        records.push(
          if changes.is_empty() {
            Fixed(initial)
          } else {
            Dated(initial, changes)
          },
        )
      }
      _ => records.push(Fixed(offsets[0]))
    }
  }
  let endpoints = [records[0], records.last().unwrap()].mapi((i, record) => {
    match record {
      Fixed(offset) => Recurring::Fixed(offset)
      Annual(rule) => Windows(rule)
      Dated(initial, changes) =>
        Fixed(if i == 0 { initial } else { changes.last().unwrap().1 })
    }
  })
  if records.length() == 1 && !(records[0] is Dated(_, _)) {
    let rule = endpoints[0]
    return {
      id,
      rules: Stored({
        offsets: rule.offsets(),
        transitions: [],
        past: None,
        future: if rule is Fixed(_) {
          None
        } else {
          Some((@int64.MIN_VALUE, rule))
        },
      }),
    }
  }
  let table_first = first
  let table_last = last
  // Absolute endpoint dates remain one-off events even outside the registry's
  // year bounds. Expand only the finite span containing those dates.
  let first = match records[0] {
    Dated(_, changes) => {
      // Include a neighboring year because UTC and local years can differ.
      let year = fixed_days_to_year_ord(
          changes[0].0 / 86400L + days_zero_year_to_unix_epoch,
        ).0 -
        1
      if table_first == 0 {
        year
      } else {
        table_first.min(year)
      }
    }
    _ => table_first
  }
  let last = match records.last().unwrap() {
    Dated(_, changes) => {
      let year = fixed_days_to_year_ord(
          changes.last().unwrap().0 / 86400L + days_zero_year_to_unix_epoch,
        ).0 +
        1
      table_last.max(year)
    }
    _ => table_last
  }
  let cutoff = records[0].year_boundary(first)
  let mut previous = records[0].lookup_offset(first - 1, cutoff - 1)
  let offsets : Array[ZoneOffset] = []
  let indices : Map[(Int32, Bool), Int32] = Map([])
  let transitions : Array[(Int64, Int32)] = []
  let mut finish = cutoff
  for year in first..<=last {
    let index = (year - table_first).clamp(min=0, max=records.length() - 1)
    let record = records[index]
    let begin = finish
    finish = record.year_boundary(year + 1)
    let changes = [begin]
    match record {
      Annual(windows) => {
        if windows.start != YearBoundary {
          changes.push(windows.start.time(year, windows.standard.seconds()))
        }
        if windows.end != YearBoundary {
          changes.push(windows.end.time(year, windows.daylight.seconds()))
        }
      }
      Dated(_, events) =>
        for (time, _) in events {
          changes.push(time)
        }
      Fixed(_) => ()
    }
    changes.sort()
    for time in changes {
      if time < begin || time >= finish {
        continue
      }
      let offset = record.lookup_offset(year, time)
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
    rules: Stored({
      offsets,
      transitions,
      past: Some((cutoff, endpoints[0])),
      future: Some((finish, endpoints[1])),
    }),
  }
}

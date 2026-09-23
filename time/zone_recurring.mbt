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
// Each variant retains its source's annual semantics behind the same pure
// queries. Explicit dated transitions belong to Zone's historical table.
// Offsets are checked once when loading. Lookup then needs only portable,
// non-throwing calendar arithmetic, including for timestamps outside Int years.
// Windows construction is exercised by white-box tests until its loader lands.
#warnings("-unused_constructor")
priv enum Recurring {
  Fixed(ZoneOffset)
  Tzif(
    standard~ : ZoneOffset,
    daylight~ : ZoneOffset,
    start~ : @tzif.Rule,
    end~ : @tzif.Rule
  )
  Windows(WindowsRule)
} derive(Eq, Debug)

///|
fn Recurring::from_posix(tz : @tzif.PosixTz) -> Recurring raise Error {
  let standard = ZoneOffset::from_seconds(tz.standard_offset)
  let standard = { ..standard, abbrev: tz.standard_designation, dst: false, }
  match tz.daylight {
    None => Fixed(standard)
    Some(daylight) => {
      guard daylight.rules is Some((start, end)) else {
        raise Failure::Failure(
          "TZif daylight footer requires explicit transition rules",
        )
      }
      let offset = ZoneOffset::from_seconds(daylight.offset)
      let daylight = { ..offset, abbrev: daylight.designation, dst: true, }
      Tzif(standard~, daylight~, start~, end~)
    }
  }
}

///|
fn Recurring::lookup_offset(self : Recurring, secs : Int64) -> ZoneOffset {
  match self {
    Fixed(offset) => offset
    Windows(rule) => rule.lookup_offset(secs)
    Tzif(standard~, daylight~, start~, end~) => {
      // Gregorian dates and weekdays repeat every 400 years. Reduce first so
      // even Int64 endpoints cannot overflow while applying rule times and
      // offsets. The representative timestamp lies in 1970 through 2369.
      let cycle_seconds = days_per_400_years * 86400L
      let remainder = secs % cycle_seconds
      let second = if remainder < 0L {
        remainder + cycle_seconds
      } else {
        remainder
      }
      let (year, _) = fixed_days_to_year_ord(
        second / 86400L + days_zero_year_to_unix_epoch,
      )
      // Consider neighboring nominal years because signed times and offsets
      // can move their transitions across UTC year boundaries. Two preceding
      // years also cover a winter season whose December start falls in January.
      for year in (year - 2)..<=(year + 1) {
        let enter = tzif_rule_time(start, year, standard.seconds())
        let leave = for end_year = year {
          let leave = tzif_rule_time(end, end_year, daylight.seconds())
          if leave > enter {
            break leave
          }
          // A winter season ends in a following nominal year. Validated rule
          // times can spill at most a week, so at most two advances are needed.
          continue end_year + 1
        }
        // Adjacent or overlapping seasons leave no standard-time gap. Testing
        // interval membership handles all-year DST without inventing an end
        // transition that would cancel the next season (RFC 9636, 3.3.1).
        if enter <= second && second < leave {
          return daylight
        }
      }
      standard
    }
  }
}

///|
fn Recurring::offsets(self : Recurring) -> Array[ZoneOffset] {
  match self {
    Fixed(offset) => [offset]
    Tzif(standard~, daylight~, ..) => [standard, daylight]
    Windows(rule) => [rule.standard, rule.daylight]
  }
}

///|
// Return candidate changes around a local year. The caller clips them to the
// rule's scope and checks the actual offsets on both sides, so redundant rule
// dates (including all-year DST) cannot invent a gap.
fn Recurring::transitions_near(self : Recurring, year : Int) -> Array[Int64] {
  let changes = []
  for year in (year - 1)..<=(year + 1) {
    match self {
      Fixed(_) => ()
      Tzif(standard~, daylight~, start~, end~) => {
        changes.push(tzif_rule_time(start, year, standard.seconds()))
        changes.push(tzif_rule_time(end, year, daylight.seconds()))
      }
      Windows(rule) => {
        changes.push(rule.year_boundary(year))
        if rule.start != YearBoundary {
          changes.push(rule.start.time(year, rule.standard.seconds()))
        }
        if rule.end != YearBoundary {
          changes.push(rule.end.time(year, rule.daylight.seconds()))
        }
      }
    }
  }
  changes
}

///|
// POSIX start times use the standard offset; end times use the daylight
// offset. The date is local wall time and may spill into another day or year.
fn tzif_rule_time(rule : @tzif.Rule, year : Int, offset : Int) -> Int64 {
  let day = match rule.day {
    JulianNoLeap(n) =>
      date_to_fixed_days(year, 1, 1) +
      (n - 1 + (if n >= 60 && check_leap_year(year) { 1 } else { 0 })).to_int64()
    DayOfYear(n) => date_to_fixed_days(year, 1, 1) + n.to_int64()
    MonthWeekDay(month~, week~, weekday~) => {
      let first = date_to_fixed_days(year, month, 1)
      // Day zero (0000-01-01) was Saturday, or 6 with Sunday numbered zero.
      let first_weekday = ((first + 6L) % 7L).to_int()
      let day = 1 + (weekday - first_weekday + 7) % 7 + (week - 1) * 7
      let day = if day > calc_days_in_month(year, month) {
        day - 7
      } else {
        day
      }
      first + (day - 1).to_int64()
    }
  }
  (day - days_zero_year_to_unix_epoch) * 86400L +
  rule.time.to_int64() -
  offset.to_int64()
}

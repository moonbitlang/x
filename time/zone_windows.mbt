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
// One normalized annual rule, without OS handles or a multi-year database.
// The Windows loader validates offsets and dates before constructing it.
// Absolute SYSTEMTIME dates belong in the explicit transition history.
priv struct WindowsRule {
  standard : ZoneOffset
  daylight : ZoneOffset
  start : WindowsDate
  end : WindowsDate
} derive(Eq, Debug)

///|
#warnings("-unused_constructor")
priv enum WindowsDate {
  // month: 1..12, week: 1..5 (5 means last), weekday: Sunday=0..Saturday=6.
  // second is local wall time in 0..86400; 86400 denotes next midnight.
  MonthWeekDay(month~ : Int, week~ : Int, weekday~ : Int, second~ : Int)
  // As a start: already in DST at year's start. As an end: still in DST
  // at year's end. This is a state marker, not a literal clock change.
  // Semantics follow the marker predicates in .NET's AdjustmentRule:
  // https://github.com/dotnet/runtime/blob/v10.0.0/src/libraries/System.Private.CoreLib/src/System/TimeZoneInfo.AdjustmentRule.cs
  YearBoundary
} derive(Eq, Debug)

///|
fn WindowsDate::time(self : WindowsDate, year : Int, offset : Int) -> Int64 {
  let (day, second) = match self {
    YearBoundary => (date_to_fixed_days(year, 1, 1), 0)
    MonthWeekDay(month~, week~, weekday~, second~) => {
      let first = date_to_fixed_days(year, month, 1)
      let first_weekday = (((first + 6L) % 7L + 7L) % 7L).to_int()
      let day = 1 + (weekday - first_weekday + 7) % 7 + (week - 1) * 7
      let day = if day > calc_days_in_month(year, month) {
        day - 7
      } else {
        day
      }
      (first + (day - 1).to_int64(), second)
    }
  }
  (day - days_zero_year_to_unix_epoch) * 86400L +
  second.to_int64() -
  offset.to_int64()
}

///|
fn WindowsRule::offset_in_year(
  self : WindowsRule,
  year : Int,
  second : Int64,
) -> ZoneOffset {
  let daylight = match (self.start, self.end) {
    (YearBoundary, YearBoundary) => true
    (YearBoundary, end) => second < end.time(year, self.daylight.seconds())
    (start, YearBoundary) => second >= start.time(year, self.standard.seconds())
    (start, end) => {
      let enter = start.time(year, self.standard.seconds())
      let leave = end.time(year, self.daylight.seconds())
      start != end &&
      (if enter < leave {
        enter <= second && second < leave
      } else {
        enter != leave && (second < leave || second >= enter)
      })
    }
  }
  if daylight {
    self.daylight
  } else {
    self.standard
  }
}

///|
fn WindowsRule::ending_offset(self : WindowsRule, year : Int) -> ZoneOffset {
  let daylight = match (self.start, self.end) {
    (_, YearBoundary) => true
    (YearBoundary, _) => false
    (start, end) => start.time(year, 0) > end.time(year, 0)
  }
  if daylight {
    self.daylight
  } else {
    self.standard
  }
}

///|
// The preceding year's final offset locates the next annual rule's start
// in UTC. Candidate transitions include this instant even if no clock moves.
fn WindowsRule::year_boundary(self : WindowsRule, year : Int) -> Int64 {
  (date_to_fixed_days(year, 1, 1) - days_zero_year_to_unix_epoch) * 86400L -
  self.ending_offset(year - 1).seconds().to_int64()
}

///|
fn WindowsRule::lookup_offset(self : WindowsRule, secs : Int64) -> ZoneOffset {
  // Gregorian calendars repeat every 400 years. Reduce before adding offsets
  // so recurrence lookup is safe even at the Int64 endpoints.
  let cycle = days_per_400_years * 86400L
  let wall = secs % cycle + self.standard.seconds().to_int64()
  let wall = (wall % cycle + cycle) % cycle
  let second = wall - self.standard.seconds().to_int64()
  let (year, _) = fixed_days_to_year_ord(
    wall / 86400L + days_zero_year_to_unix_epoch,
  )
  let year = if second < self.year_boundary(year) {
    year - 1
  } else if second >= self.year_boundary(year + 1) {
    year + 1
  } else {
    year
  }
  self.offset_in_year(year, second)
}

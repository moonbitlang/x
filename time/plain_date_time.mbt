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
/// A datetime without a time zone in the ISO 8601 calendar system.
struct PlainDateTime {
  date : PlainDate
  time : PlainTime
} derive(Debug, ToJson, FromJson, Hash)

///|
/// Creates a PlainDateTime from the year, month, day, hour, minute, second and nanosecond.
pub fn PlainDateTime::of(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
) -> PlainDateTime raise Error {
  {
    date: PlainDate::of(year, month, day),
    time: PlainTime::of(hour, minute, second, nanosecond),
  }
}

///|
/// Creates a PlainDateTime from the elapsed seconds since the unix epoch.
pub fn PlainDateTime::from_unix_second(
  second : Int64,
  nanosecond : Int,
  offset : ZoneOffset,
) -> PlainDateTime raise Error {
  if !validate_nano(nanosecond) {
    fail(invalid_date_time_err)
  }
  let sec = second + offset.seconds().to_int64()
  let unix_day = floor_div_int64(sec, seconds_per_day)
  let seconds_of_day = floor_mod_int64(sec, seconds_per_day)
  let date = PlainDate::from_unix_day(unix_day)
  let time = PlainTime::from_nanosecond_of_day(
    seconds_of_day * nanoseconds_per_second + nanosecond.to_int64(),
  )
  { date, time, }
}

///|
/// Converts this datetime to the elapsed seconds since the unix epoch.
pub fn PlainDateTime::to_unix_second(self : PlainDateTime) -> Int64 {
  self.date.to_unix_day() * seconds_per_day +
  self.time.second_of_day().to_int64()
}

///|
/// Creates a PlainTime from a string, like '2008-08-08T20:00:00'.
#deprecated("Use `PlainDateTime::from_str` instead")
pub fn PlainDateTime::from_string(str : String) -> PlainDateTime raise Error {
  PlainDateTime::parse_str(str)
}

///|
fn PlainDateTime::parse_str(str : StringView) -> PlainDateTime raise Error {
  guard str.split("T").to_array() is [date_str, time_str] else {
    fail(invalid_date_time_err)
  }
  let date = PlainDate::parse_str(date_str) catch {
    _ => fail(invalid_date_time_err)
  }
  let time = PlainTime::parse_str(time_str) catch {
    _ => fail(invalid_date_time_err)
  }
  PlainDateTime::{ date, time, }
}

///|
pub impl @string.FromStr for PlainDateTime with fn from_str(str) {
  PlainDateTime::parse_str(str)
}

///|
/// Returns a string representing the datetime.
pub fn PlainDateTime::to_string(self : PlainDateTime) -> String {
  let buf = StringBuilder(size_hint=18)
  buf.write_string(self.date.to_string())
  buf.write_char('T')
  buf.write_string(self.time.to_string())
  buf.to_string()
}

///|
pub impl Show for PlainDateTime with fn output(
  self : PlainDateTime,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for PlainDateTime with fn equal(
  self : PlainDateTime,
  other : PlainDateTime,
) -> Bool {
  Compare::compare(self, other) == 0
}

///|
pub impl Compare for PlainDateTime with fn compare(
  self : PlainDateTime,
  other : PlainDateTime,
) -> Int {
  if self.date > other.date {
    1
  } else if self.date < other.date {
    -1
  } else if self.time > other.time {
    1
  } else if self.time < other.time {
    -1
  } else {
    0
  }
}

///|
/// Returns the era of this datetime.
pub fn PlainDateTime::era(self : PlainDateTime) -> String {
  self.date.era()
}

///|
/// Returns the year of era of this datetime.
pub fn PlainDateTime::era_year(self : PlainDateTime) -> Int {
  self.date.era_year()
}

///|
/// Returns the year of this datetime.
pub fn PlainDateTime::year(self : PlainDateTime) -> Int {
  self.date.year()
}

///|
/// Returns the month of this datetime.
pub fn PlainDateTime::month(self : PlainDateTime) -> Int {
  self.date.month()
}

///|
/// Returns the day of month of this datetime.
pub fn PlainDateTime::day(self : PlainDateTime) -> Int {
  self.date.day()
}

///|
/// Returns the calendar month code, e.g. "M01" .. "M12", of this datetime.
pub fn PlainDateTime::month_code(self : PlainDateTime) -> String {
  self.date.month_code()
}

///|
/// Returns the weekday of this datetime.
pub fn PlainDateTime::weekday(self : PlainDateTime) -> Weekday {
  self.date.weekday()
}

///|
/// Returns the ISO 8601 day of the week as an integer
/// (1 = Monday .. 7 = Sunday) of this datetime.
pub fn PlainDateTime::day_of_week(self : PlainDateTime) -> Int {
  self.date.day_of_week()
}

///|
/// Returns the ordinal day of year of this datetime.
pub fn PlainDateTime::ordinal(self : PlainDateTime) -> Int {
  self.date.ordinal()
}

///|
/// Returns the ISO 8601 week number (1-53) of this datetime.
pub fn PlainDateTime::week_of_year(self : PlainDateTime) -> Int {
  self.date.week_of_year()
}

///|
/// Returns the ISO 8601 week-numbering year of this datetime.
pub fn PlainDateTime::year_of_week(self : PlainDateTime) -> Int {
  self.date.year_of_week()
}

///|
/// Returns the number of days in a week of this datetime.
pub fn PlainDateTime::days_in_week(self : PlainDateTime) -> Int {
  self.date.days_in_week()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn PlainDateTime::days_in_month(self : PlainDateTime) -> Int {
  self.date.days_in_month()
}

///|
/// Returns the number of days in a year of this datetime.
pub fn PlainDateTime::days_in_year(self : PlainDateTime) -> Int {
  self.date.days_in_year()
}

///|
/// Returns the number of months in a year of this datetime.
pub fn PlainDateTime::months_in_year(self : PlainDateTime) -> Int {
  self.date.months_in_year()
}

///|
/// Checks if this datetime is in a leap year.
pub fn PlainDateTime::in_leap_year(self : PlainDateTime) -> Bool {
  self.date.in_leap_year()
}

///|
/// Returns the hour of this datetime.
pub fn PlainDateTime::hour(self : PlainDateTime) -> Int {
  self.time.hour()
}

///|
/// Returns the minute of this datetime.
pub fn PlainDateTime::minute(self : PlainDateTime) -> Int {
  self.time.minute()
}

///|
/// Returns the second of this datetime.
pub fn PlainDateTime::second(self : PlainDateTime) -> Int {
  self.time.second()
}

///|
/// Returns the nanosecond-of-second of this datetime.
pub fn PlainDateTime::nanosecond(self : PlainDateTime) -> Int {
  self.time.nanosecond()
}

///|
/// Returns the millisecond-of-second component (0-999) of this datetime.
pub fn PlainDateTime::millisecond(self : PlainDateTime) -> Int {
  self.time.millisecond()
}

///|
/// Returns the microsecond-of-second component (0-999) of this datetime.
pub fn PlainDateTime::microsecond(self : PlainDateTime) -> Int {
  self.time.microsecond()
}

///|
/// Returns whether this datetime is the same as `other`. 
pub fn PlainDateTime::equals(
  self : PlainDateTime,
  other : PlainDateTime,
) -> Bool {
  Compare::compare(self, other) == 0
}

///|
/// Returns whichever of the two datetimes is earlier (or `a` if equal).
pub fn PlainDateTime::min(
  a : PlainDateTime,
  b : PlainDateTime,
) -> PlainDateTime {
  if Compare::compare(a, b) <= 0 {
    a
  } else {
    b
  }
}

///|
/// Returns whichever of the two datetimes is later (or `a` if equal).
pub fn PlainDateTime::max(
  a : PlainDateTime,
  b : PlainDateTime,
) -> PlainDateTime {
  if Compare::compare(a, b) >= 0 {
    a
  } else {
    b
  }
}

///|
/// Adds specified years to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_years(
  self : PlainDateTime,
  years : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.add_years(years), }
}

///|
/// Subtracts specified years from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_years(
  self : PlainDateTime,
  years : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.subtract_years(years), }
}

///|
/// Adds specified months to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_months(
  self : PlainDateTime,
  months : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.add_months(months), }
}

///|
/// Subtracts specified months from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_months(
  self : PlainDateTime,
  months : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.subtract_months(months), }
}

///|
/// Adds specified weeks to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_weeks(
  self : PlainDateTime,
  weeks : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.add_weeks(weeks), }
}

///|
/// Subtracts specified weeks from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_weeks(
  self : PlainDateTime,
  weeks : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.subtract_weeks(weeks), }
}

///|
/// Adds specified days to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_days(
  self : PlainDateTime,
  days : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.add_days(days), }
}

///|
/// Subtracts specified days from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_days(
  self : PlainDateTime,
  days : Int64,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.subtract_days(days), }
}

///|
/// Adds a period of date to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_period(
  self : PlainDateTime,
  period : Period,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.add_period(period), }
}

///|
/// Subtracts a period of date from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_period(
  self : PlainDateTime,
  period : Period,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.subtract_period(period), }
}

///|
/// Adds specified hours to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_hours(
  self : PlainDateTime,
  hours : Int64,
) -> PlainDateTime raise Error {
  if hours == 0L {
    return self
  }
  self.overflowing_add(h=hours)
}

///|
/// Subtracts specified hours from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_hours(
  self : PlainDateTime,
  hours : Int64,
) -> PlainDateTime raise Error {
  if hours == 0L {
    return self
  }
  self.overflowing_add(h=-hours)
}

///|
/// Adds specified minutes to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_minutes(
  self : PlainDateTime,
  minutes : Int64,
) -> PlainDateTime raise Error {
  if minutes == 0L {
    return self
  }
  self.overflowing_add(m=minutes)
}

///|
/// Subtracts specified minutes from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_minutes(
  self : PlainDateTime,
  minutes : Int64,
) -> PlainDateTime raise Error {
  if minutes == 0L {
    return self
  }
  self.overflowing_add(m=-minutes)
}

///|
/// Adds specified seconds to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_seconds(
  self : PlainDateTime,
  seconds : Int64,
) -> PlainDateTime raise Error {
  if seconds == 0L {
    return self
  }
  self.overflowing_add(s=seconds)
}

///|
/// Subtracts specified seconds from this datetime, and returns a new datetime.
pub fn PlainDateTime::subtract_seconds(
  self : PlainDateTime,
  seconds : Int64,
) -> PlainDateTime raise Error {
  if seconds == 0L {
    return self
  }
  self.overflowing_add(s=-seconds)
}

///|
/// Adds specified nanoseconds to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_nanoseconds(
  self : PlainDateTime,
  nanoseconds : Int64,
) -> PlainDateTime raise Error {
  if nanoseconds == 0L {
    return self
  }
  self.overflowing_add(ns=nanoseconds)
}

///|
/// Subtracts specified nanoseconds from this datetime, and returns a new
/// datetime.
pub fn PlainDateTime::subtract_nanoseconds(
  self : PlainDateTime,
  nanoseconds : Int64,
) -> PlainDateTime raise Error {
  if nanoseconds == 0L {
    return self
  }
  self.overflowing_add(ns=-nanoseconds)
}

///|
/// Adds a duration of time to this datetime, and returns a new datetime.
pub fn PlainDateTime::add_duration(
  self : PlainDateTime,
  duration : Duration,
) -> PlainDateTime raise Error {
  if duration.is_zero() {
    return self
  }
  self.overflowing_add(s=duration.secs, ns=duration.nanos.to_int64())
}

///|
/// Subtracts a duration of time from this datetime, and returns a new
/// datetime.
pub fn PlainDateTime::subtract_duration(
  self : PlainDateTime,
  duration : Duration,
) -> PlainDateTime raise Error {
  if duration.is_zero() {
    return self
  }
  self.overflowing_add(s=-duration.secs, ns=-duration.nanos.to_int64())
}

///|
/// Adds a period-duration to this datetime: the period is applied to the
/// date part first, then the duration is applied on top (with overflow
/// carried across day boundaries). This order matches the period-before-
/// time convention `PeriodDuration` itself uses in its ISO string form
/// (`P1Y2M3DT4H5M6S`).
///
/// Note that period and duration application don't always commute — e.g.
/// near end-of-month, adding the period first vs. the duration first can
/// land on a different date if both operations overflow. This method
/// always applies period, then duration.
pub fn PlainDateTime::add_period_duration(
  self : PlainDateTime,
  period_duration : PeriodDuration,
) -> PlainDateTime raise Error {
  if period_duration.is_zero() {
    return self
  }
  self
  .add_period(period_duration.period())
  .add_duration(period_duration.duration())
}

///|
/// Subtracts a period-duration from this datetime. To exactly invert
/// `add_period_duration`, this subtracts the duration first and then the
/// period — the reverse order of how `add_period_duration` applies them.
pub fn PlainDateTime::subtract_period_duration(
  self : PlainDateTime,
  period_duration : PeriodDuration,
) -> PlainDateTime raise Error {
  if period_duration.is_zero() {
    return self
  }
  self
  .subtract_duration(period_duration.duration())
  .subtract_period(period_duration.period())
}

///|
/// Returns a new datetime with the specified year.
pub fn PlainDateTime::with_year(
  self : PlainDateTime,
  year : Int,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.with_year(year), }
}

///|
/// Returns a new datetime with the specified month.
pub fn PlainDateTime::with_month(
  self : PlainDateTime,
  month : Int,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.with_month(month), }
}

///|
/// Returns a new datetime with the specified day of month.
pub fn PlainDateTime::with_day(
  self : PlainDateTime,
  day : Int,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.with_day(day), }
}

///|
/// Returns a new datetime with the specified ordinal day of year.
pub fn PlainDateTime::with_ordinal(
  self : PlainDateTime,
  ordinal : Int,
) -> PlainDateTime raise Error {
  { ..self, date: self.date.with_ordinal(ordinal), }
}

///|
/// Returns a new datetime with the specified hour.
pub fn PlainDateTime::with_hour(
  self : PlainDateTime,
  hour : Int,
) -> PlainDateTime raise Error {
  { ..self, time: self.time.with_hour(hour), }
}

///|
/// Returns a new datetime with the specified minute.
pub fn PlainDateTime::with_minute(
  self : PlainDateTime,
  minute : Int,
) -> PlainDateTime raise Error {
  { ..self, time: self.time.with_minute(minute), }
}

///|
/// Returns a new datetime with the specified second.
pub fn PlainDateTime::with_second(
  self : PlainDateTime,
  second : Int,
) -> PlainDateTime raise Error {
  { ..self, time: self.time.with_second(second), }
}

///|
/// Returns a new datetime with the specified nanosecond.
pub fn PlainDateTime::with_nanosecond(
  self : PlainDateTime,
  nanosecond : Int,
) -> PlainDateTime raise Error {
  { ..self, time: self.time.with_nanosecond(nanosecond), }
}

///|
/// Returns a new datetime with any of year, month, day, hour, minute,
/// second, or nanosecond replaced, leaving unspecified fields unchanged.
pub fn PlainDateTime::modify_with(
  self : PlainDateTime,
  year? : Int,
  month? : Int,
  day? : Int,
  hour? : Int,
  minute? : Int,
  second? : Int,
  nanosecond? : Int,
) -> PlainDateTime raise Error {
  let date = self.date.modify_with(year?, month?, day?)
  let time = self.time.modify_with(hour?, minute?, second?, nanosecond?)
  { date, time, }
}

///|
/// Returns the exact elapsed duration between this datetime and another,
/// spanning any number of days.
pub fn PlainDateTime::until(
  self : PlainDateTime,
  end : PlainDateTime,
) -> Duration raise Error {
  let day_diff = end.date.to_unix_day() - self.date.to_unix_day()
  let nanos_diff = end.time.nanosecond_of_day() - self.time.nanosecond_of_day()
  // Fold the day difference into whole seconds first: multiplying the day
  // difference by `nanoseconds_per_day` overflows Int64 after ~292 years.
  Duration::of(seconds=day_diff * seconds_per_day, nanoseconds=nanos_diff)
}

///|
/// Returns the exact elapsed duration since another datetime.
pub fn PlainDateTime::since(
  self : PlainDateTime,
  other : PlainDateTime,
) -> Duration raise Error {
  other.until(self)
}

///|
/// Returns the date part of this datetime.
pub fn PlainDateTime::to_plain_date(self : PlainDateTime) -> PlainDate {
  self.date
}

///|
/// Returns the time part of this datetime.
pub fn PlainDateTime::to_plain_time(self : PlainDateTime) -> PlainTime {
  self.time
}

// *****************************
// * internal helper functions *
// *****************************

///|
fn PlainDateTime::overflowing_add(
  self : PlainDateTime,
  h? : Int64 = 0L,
  m? : Int64 = 0L,
  s? : Int64 = 0L,
  ns? : Int64 = 0L,
) -> PlainDateTime raise Error {
  if h == 0L && m == 0L && s == 0L && ns == 0L {
    return self
  }
  let mut date = self.date
  let days_to_add = h / hours_per_day +
    m / minutes_per_day +
    s / seconds_per_day +
    ns / nanoseconds_per_day
  let nanos_to_add = h % hours_per_day * nanoseconds_per_hour +
    m % minutes_per_day * nanoseconds_per_minute +
    s % seconds_per_day * nanoseconds_per_second +
    ns % nanoseconds_per_day
  let current_nanos = self.time.nanosecond_of_day()
  let mut total_nanos = current_nanos + nanos_to_add
  let total_days = days_to_add +
    floor_div_int64(total_nanos, nanoseconds_per_day)
  total_nanos = floor_mod_int64(total_nanos, nanoseconds_per_day)
  let time = if current_nanos == total_nanos {
    self.time
  } else {
    PlainTime::from_nanosecond_of_day(total_nanos)
  }
  date = date.add_days(total_days)
  { date, time, }
}

///|
#deprecated
pub extend PlainDateTime with Eq::{not_equal, equal}

///|
#deprecated
pub extend PlainDateTime with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
pub extend PlainDateTime with Debug::{to_repr}

///|
#deprecated
pub extend PlainDateTime with @string.FromStr::{from_str}

///|
#deprecated
pub extend PlainDateTime with Show::{output}

///|
#deprecated
pub extend PlainDateTime with ToJson::{to_json}

///|
#deprecated
pub extend PlainDateTime with FromJson::{from_json}

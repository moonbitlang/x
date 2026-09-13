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
/// A datetime with a time zone and offset in the ISO 8601 calendar system.
struct ZonedDateTime {
  datetime : PlainDateTime
  zone : Zone
  offset : ZoneOffset
} derive(Debug)

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute, second and a time zone.
/// The default time zone is UTC+0.
pub fn date_time(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
    zone~,
  )
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn unix(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::from_unix_second(second, nanosecond~, zone~)
}

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute and second.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::of(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let datetime = PlainDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
  )
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from a PlainDateTime and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_plain_datetime(
  datetime : PlainDateTime,
  zone? : Zone = utc_zone,
) -> ZonedDateTime {
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_unix_second(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let offset = zone.lookup_offset(second)
  let datetime = PlainDateTime::from_unix_second(second, nanosecond, offset)
  { datetime, zone, offset, }
}

///|
/// Returns a string representing this datetime, like "2008-08-08T20:00:00+8:00[Asia/Beijing]"
pub fn ZonedDateTime::to_string(self : ZonedDateTime) -> String {
  let buf = StringBuilder(size_hint=0)
  buf.write_string(self.datetime.to_string())
  buf.write_string(self.offset.to_string())
  if self.zone != utc_zone && self.zone.id != "" {
    buf.write_char('[')
    let abbrev = self.offset.abbreviation()
    if abbrev == "" {
      buf.write_string(self.zone.to_string())
    } else {
      buf.write_string(abbrev)
    }
    buf.write_char(']')
  }
  buf.to_string()
}

///|
pub impl @string.FromStr for ZonedDateTime with fn from_str(str) {
  ZonedDateTime::parse_str(str)
}

///|
/// Parses a RFC 3339 string with an optional bracketed time zone id, like
/// `2008-08-08T20:00:00Z`, `2008-08-08T20:00:00Z[UTC]`,
/// `2008-08-08T20:00:00+08:00[Asia/Shanghai]` or
/// `2008-08-08T20:00:00.123456789+08:00[Asia/Shanghai]`.
///
/// The offset is required. The bracketed id is represented as a fixed-offset
/// zone built from the parsed offset; this function does not look up the
/// IANA/TZData rules of the id. A value without a bracketed id carries a zone
/// with an empty id.
pub fn ZonedDateTime::parse_str(str : StringView) -> ZonedDateTime raise Error {
  guard str.length() >= 20 else { fail(invalid_zoned_date_time_err) }
  // `[-]YYYY-MM-DDTHH:MM:SS`, optionally followed by fractional seconds.
  lexmatch str with longest {
    // 2008-08-08T20:00:00Z, 2008-08-08T20:00:00.123456789Z
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    re"Z$" => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      ZonedDateTime::{
        datetime: date_time,
        zone: utc_zone,
        offset: utc_offset,
      }
    }
    // 2008-08-08T20:00:00Z[UTC], 2008-08-08T20:00:00.123456789Z[Asia/Shanghai]
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"Z\[[^\[\]]+\]$" as _zone) => {
      // `to_string` renders a zero offset as `Z` followed by the bracketed
      // abbreviation, so `Z[...]` values have to be readable back.
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let zone = parse_zone(_zone, utc_offset)
      ZonedDateTime::{ datetime: date_time, zone, offset: utc_offset, }
    }
    // 2008-08-08T20:00:00.123456789+08:00, 2008-08-08T20:00:00+08:00
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"[+\-:0-9]{6}$" as _zone_offset) => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let offset = ZoneOffset::parse_str(_zone_offset) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      // The parsed offset is the only offset of the zone, so calculations do
      // not shift the instant. The empty id marks a value without a bracketed
      // zone id.
      let zone = Zone::fixed_zone("", offset.seconds())
      ZonedDateTime::{ datetime: date_time, zone, offset, }
    }
    // 2008-08-08T20:00:00.123456789+08:00[Asia/Shanghai], 2026-09-12T14:30:00-05:00[America/New_York]
    (re"^-?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:\.]{8,}" as _plain_datetime) +
    (re"[+\-:0-9]{6}" as _zone_offset) +
    (re"\[[^\[\]]+\]$" as _zone) => {
      let date_time = PlainDateTime::parse_str(_plain_datetime) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let offset = ZoneOffset::parse_str(_zone_offset) catch {
        _ => fail(invalid_zoned_date_time_err)
      }
      let zone = parse_zone(_zone, offset)
      ZonedDateTime::{ datetime: date_time, zone, offset, }
    }
    _ => fail(invalid_zoned_date_time_err)
  }
}

///|
/// Parses a bracketed zone annotation like `[Asia/Shanghai]`, or the `Z[UTC]`
/// form, into a fixed-offset zone built from `offset`.
fn parse_zone(str : StringView, offset : ZoneOffset) -> Zone raise {
  lexmatch str with longest {
    re"^Z?\[" + (re"[^\[\]]{2,}" as zone_id) + re"\]$" =>
      Zone::fixed_zone(zone_id.to_owned(), offset.seconds())
    _ => fail(invalid_zoned_date_time_err)
  }
}

///|
pub impl Show for ZonedDateTime with fn output(
  self : ZonedDateTime,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for ZonedDateTime with fn to_json(self : ZonedDateTime) -> Json {
  Json(self.to_string())
}

///|
pub impl FromJson for ZonedDateTime with fn from_json(json, path) -> ZonedDateTime raise {
  guard json is Json::String(str) else {
    raise @json.JsonDecodeError(
      (path, "ZonedDateTime: expected string \{Repr(json)}"),
    )
  }
  let zdt : ZonedDateTime = @string.FromStr::from_str(str) catch {
    _e =>
      raise @json.JsonDecodeError(
        (path, "ZonedDateTime: Invalid RFC3339 string \{str}"),
      )
  }
  zdt
}

///|
/// Two datetimes are equal when they denote the same instant; see `Compare`.
pub impl Eq for ZonedDateTime with fn equal(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Bool {
  Compare::compare(self, other) == 0
}

///|
/// Compares two datetimes by the instant they denote.
///
/// The zone and offset are not part of the comparison: two datetimes denoting
/// the same instant are equal even when they are in different zones.
/// Nanoseconds are significant.
pub impl Compare for ZonedDateTime with fn compare(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Int {
  let self_second = self.to_unix_second()
  let other_second = other.to_unix_second()
  if self_second > other_second {
    1
  } else if self_second < other_second {
    -1
  } else if self.nanosecond() > other.nanosecond() {
    1
  } else if self.nanosecond() < other.nanosecond() {
    -1
  } else {
    0
  }
}

///|
/// Returns the elapsed seconds since the unix epoch.
pub fn ZonedDateTime::to_unix_second(self : ZonedDateTime) -> Int64 {
  self.datetime.to_unix_second() - self.offset.seconds().to_int64()
}

///|
/// Returns the date part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date(self : ZonedDateTime) -> PlainDate {
  self.datetime.to_plain_date()
}

///|
/// Returns the time part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_time(self : ZonedDateTime) -> PlainTime {
  self.datetime.to_plain_time()
}

///|
/// Returns the datetime part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date_time(self : ZonedDateTime) -> PlainDateTime {
  self.datetime
}

///|
/// Returns the era of this datetime.
pub fn ZonedDateTime::era(self : ZonedDateTime) -> String {
  self.datetime.era()
}

///|
/// Returns the year of era of this datetime.
pub fn ZonedDateTime::era_year(self : ZonedDateTime) -> Int {
  self.datetime.era_year()
}

///|
/// Returns the year of this datetime.
pub fn ZonedDateTime::year(self : ZonedDateTime) -> Int {
  self.datetime.year()
}

///|
/// Returns the month of this datetime.
pub fn ZonedDateTime::month(self : ZonedDateTime) -> Int {
  self.datetime.month()
}

///|
/// Returns the day of month of this datetime.
pub fn ZonedDateTime::day(self : ZonedDateTime) -> Int {
  self.datetime.day()
}

///|
/// Returns the weekday of this datetime.
pub fn ZonedDateTime::weekday(self : ZonedDateTime) -> Weekday {
  self.datetime.weekday()
}

///|
/// Returns the ordinal day of year of this datetime.
pub fn ZonedDateTime::ordinal(self : ZonedDateTime) -> Int {
  self.datetime.ordinal()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_week(self : ZonedDateTime) -> Int {
  self.datetime.days_in_week()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_month(self : ZonedDateTime) -> Int {
  self.datetime.days_in_month()
}

///|
/// Returns the number of days in a year of this datetime.
pub fn ZonedDateTime::days_in_year(self : ZonedDateTime) -> Int {
  self.datetime.days_in_year()
}

///|
/// Returns the number of months in a year of this datetime.
pub fn ZonedDateTime::months_in_year(self : ZonedDateTime) -> Int {
  self.datetime.months_in_year()
}

///|
/// Checks if this datetime is in a leap year.
pub fn ZonedDateTime::in_leap_year(self : ZonedDateTime) -> Bool {
  self.datetime.in_leap_year()
}

///|
/// Returns the hour of this datetime.
pub fn ZonedDateTime::hour(self : ZonedDateTime) -> Int {
  self.datetime.hour()
}

///|
/// Returns the minute of this datetime.
pub fn ZonedDateTime::minute(self : ZonedDateTime) -> Int {
  self.datetime.minute()
}

///|
/// Returns the second of this datetime.
pub fn ZonedDateTime::second(self : ZonedDateTime) -> Int {
  self.datetime.second()
}

///|
/// Returns the nanosecond of this datetime.
pub fn ZonedDateTime::nanosecond(self : ZonedDateTime) -> Int {
  self.datetime.nanosecond()
}

///|
/// Returns the time zone of this datetime.
///
/// A datetime parsed from a string without a bracketed zone id carries a zone
/// with an empty id.
pub fn ZonedDateTime::zone(self : ZonedDateTime) -> Zone {
  self.zone
}

///|
/// Returns the time offset of this datetime.
pub fn ZonedDateTime::offset(self : ZonedDateTime) -> ZoneOffset {
  self.offset
}

///|
/// Adds specified years to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_years(
  self : ZonedDateTime,
  years : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_years(years), self.zone)
}

///|
/// Adds specified months to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_months(
  self : ZonedDateTime,
  months : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_months(months), self.zone)
}

///|
/// Adds specified weeks to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_weeks(
  self : ZonedDateTime,
  weeks : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_weeks(weeks), self.zone)
}

///|
/// Adds specified days to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_days(
  self : ZonedDateTime,
  days : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_days(days), self.zone)
}

///|
/// Adds specified hours to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_hours(
  self : ZonedDateTime,
  hours : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_hours(hours), self.zone)
}

///|
/// Adds specified minutes to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_minutes(
  self : ZonedDateTime,
  minutes : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_minutes(minutes), self.zone)
}

///|
/// Adds specified seconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_seconds(
  self : ZonedDateTime,
  seconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_seconds(seconds), self.zone)
}

///|
/// Adds specified nanoseconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_nanoseconds(
  self : ZonedDateTime,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_nanoseconds(nanoseconds), self.zone)
}

///|
/// Returns a new datetime with the specified year.
pub fn ZonedDateTime::with_year(
  self : ZonedDateTime,
  year : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_year(year), self.zone)
}

///|
/// Returns a new datetime with the specified month.
pub fn ZonedDateTime::with_month(
  self : ZonedDateTime,
  month : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_month(month), self.zone)
}

///|
/// Returns a new datetime with the specified day of the month.
pub fn ZonedDateTime::with_day(
  self : ZonedDateTime,
  day : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_day(day), self.zone)
}

///|
/// Returns a new datetime with the specified ordinal day of the year.
pub fn ZonedDateTime::with_ordinal(
  self : ZonedDateTime,
  ordinal : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_ordinal(ordinal), self.zone)
}

///|
/// Returns a new datetime with the specified hour.
pub fn ZonedDateTime::with_hour(
  self : ZonedDateTime,
  hour : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_hour(hour), self.zone)
}

///|
/// Returns a new datetime with the specified minute.
pub fn ZonedDateTime::with_minute(
  self : ZonedDateTime,
  minute : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_minute(minute), self.zone)
}

///|
/// Returns a new datetime with the specified second.
pub fn ZonedDateTime::with_second(
  self : ZonedDateTime,
  second : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_second(second), self.zone)
}

///|
/// Returns a new datetime with the specified nanosecond.
pub fn ZonedDateTime::with_nanosecond(
  self : ZonedDateTime,
  nanosecond : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_nanosecond(nanosecond), self.zone)
}

///|
/// Returns the calendar month code, e.g. "M01" .. "M12", of this datetime.
pub fn ZonedDateTime::month_code(self : ZonedDateTime) -> String {
  self.datetime.month_code()
}

///|
/// Returns the ISO 8601 day of the week as an integer
/// (1 = Monday .. 7 = Sunday) of this datetime.
pub fn ZonedDateTime::day_of_week(self : ZonedDateTime) -> Int {
  self.datetime.day_of_week()
}

///|
/// Returns the ISO 8601 week number (1-53) of this datetime.
pub fn ZonedDateTime::week_of_year(self : ZonedDateTime) -> Int {
  self.datetime.week_of_year()
}

///|
/// Returns the ISO 8601 week-numbering year of this datetime.
pub fn ZonedDateTime::year_of_week(self : ZonedDateTime) -> Int {
  self.datetime.year_of_week()
}

///|
/// Returns the millisecond-of-second component (0-999) of this datetime.
pub fn ZonedDateTime::millisecond(self : ZonedDateTime) -> Int {
  self.datetime.millisecond()
}

///|
/// Returns the microsecond-of-second component (0-999) of this datetime.
pub fn ZonedDateTime::microsecond(self : ZonedDateTime) -> Int {
  self.datetime.microsecond()
}

///|
/// Returns whether this datetime denotes the same instant as `other`.
/// Equivalent to `self == other`.
pub fn ZonedDateTime::equals(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Bool {
  Compare::compare(self, other) == 0
}

///|
/// Returns whichever of the two datetimes denotes the earlier instant (or
/// `a` if they're equal).
pub fn ZonedDateTime::min(
  a : ZonedDateTime,
  b : ZonedDateTime,
) -> ZonedDateTime {
  if Compare::compare(a, b) <= 0 {
    a
  } else {
    b
  }
}

///|
/// Returns whichever of the two datetimes denotes the later instant (or
/// `a` if they're equal).
pub fn ZonedDateTime::max(
  a : ZonedDateTime,
  b : ZonedDateTime,
) -> ZonedDateTime {
  if Compare::compare(a, b) >= 0 {
    a
  } else {
    b
  }
}

///|
/// Subtracts specified years from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_years(
  self : ZonedDateTime,
  years : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_years(years), self.zone)
}

///|
/// Subtracts specified months from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_months(
  self : ZonedDateTime,
  months : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_months(months), self.zone)
}

///|
/// Subtracts specified weeks from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_weeks(
  self : ZonedDateTime,
  weeks : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_weeks(weeks), self.zone)
}

///|
/// Subtracts specified days from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_days(
  self : ZonedDateTime,
  days : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_days(days), self.zone)
}

///|
/// Subtracts specified hours from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_hours(
  self : ZonedDateTime,
  hours : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_hours(hours), self.zone)
}

///|
/// Subtracts specified minutes from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_minutes(
  self : ZonedDateTime,
  minutes : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_minutes(minutes), self.zone)
}

///|
/// Subtracts specified seconds from this datetime, and returns a new datetime.
pub fn ZonedDateTime::subtract_seconds(
  self : ZonedDateTime,
  seconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_seconds(seconds), self.zone)
}

///|
/// Subtracts specified nanoseconds from this datetime, and returns a new
/// datetime.
pub fn ZonedDateTime::subtract_nanoseconds(
  self : ZonedDateTime,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_nanoseconds(nanoseconds), self.zone)
}

///|
/// Adds a period of date to this datetime, and returns a new datetime.
/// Since the period is applied to the local (wall-clock) date, the offset
/// is re-resolved for the zone afterwards — this can change the offset
/// (and therefore the instant) if the result lands on the other side of a
/// DST transition.
pub fn ZonedDateTime::add_period(
  self : ZonedDateTime,
  period : Period,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_period(period), self.zone)
}

///|
/// Subtracts a period of date from this datetime, and returns a new
/// datetime. See `add_period` regarding offset re-resolution.
pub fn ZonedDateTime::subtract_period(
  self : ZonedDateTime,
  period : Period,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.subtract_period(period), self.zone)
}

///|
/// Adds an exact-length duration to this datetime, and returns a new
/// datetime. Unlike `add_period`, this advances the actual instant by the
/// duration's length; the resulting local time and offset are then
/// derived from that instant.
pub fn ZonedDateTime::add_duration(
  self : ZonedDateTime,
  duration : Duration,
) -> ZonedDateTime raise Error {
  if duration.is_zero() {
    return self
  }
  self.shift_instant(duration.seconds(), duration.nanoseconds().to_int64())
}

///|
/// Subtracts an exact-length duration from this datetime, and returns a
/// new datetime.
pub fn ZonedDateTime::subtract_duration(
  self : ZonedDateTime,
  duration : Duration,
) -> ZonedDateTime raise Error {
  if duration.is_zero() {
    return self
  }
  self.shift_instant(
    checked_mul_int64(duration.seconds(), -1L),
    -duration.nanoseconds().to_int64(),
  )
}

///|
/// Adds a period-duration to this datetime: the period is applied to the
/// local date first, then the duration advances the instant, matching
/// `PlainDateTime::add_period_duration`.
pub fn ZonedDateTime::add_period_duration(
  self : ZonedDateTime,
  period_duration : PeriodDuration,
) -> ZonedDateTime raise Error {
  if period_duration.is_zero() {
    return self
  }
  self
  .add_period(period_duration.period())
  .add_duration(period_duration.duration())
}

///|
/// Subtracts a period-duration from this datetime — the duration first,
/// then the period — inverting `add_period_duration`.
pub fn ZonedDateTime::subtract_period_duration(
  self : ZonedDateTime,
  period_duration : PeriodDuration,
) -> ZonedDateTime raise Error {
  if period_duration.is_zero() {
    return self
  }
  self
  .subtract_duration(period_duration.duration())
  .subtract_period(period_duration.period())
}

///|
/// Returns a new datetime with any of year, month, day, hour, minute,
/// second, or nanosecond replaced, leaving unspecified fields (and the
/// zone) unchanged. The offset is re-resolved for the new local time.
pub fn ZonedDateTime::modify_with(
  self : ZonedDateTime,
  year? : Int,
  month? : Int,
  day? : Int,
  hour? : Int,
  minute? : Int,
  second? : Int,
  nanosecond? : Int,
) -> ZonedDateTime raise Error {
  let datetime = self.datetime.modify_with(
    year?,
    month?,
    day?,
    hour?,
    minute?,
    second?,
    nanosecond?,
  )
  create_from_plain(datetime, self.zone)
}

///|
/// Returns a new datetime representing the *same instant* viewed in a
/// different time zone — the wall-clock fields and offset change, the
/// instant does not. This was entirely absent before: there was no way to
/// re-view an already-constructed `ZonedDateTime` through another zone.
pub fn ZonedDateTime::with_zone(
  self : ZonedDateTime,
  zone : Zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::from_unix_second(
    self.to_unix_second(),
    nanosecond=self.nanosecond(),
    zone~,
  )
}

///|
/// Returns a new datetime representing the same instant in UTC.
/// Equivalent to `self.with_zone(utc_zone)`.
pub fn ZonedDateTime::to_utc(self : ZonedDateTime) -> ZonedDateTime raise Error {
  self.with_zone(utc_zone)
}

///|
/// Returns the exact elapsed duration between this datetime and another,
/// computed from the instants each denotes (via `to_unix_second`) rather
/// than from the local wall-clock fields — so two datetimes in different
/// zones are compared correctly.
pub fn ZonedDateTime::until(
  self : ZonedDateTime,
  end : ZonedDateTime,
) -> Duration raise Error {
  let seconds = end.to_unix_second() - self.to_unix_second()
  let nanoseconds = (end.nanosecond() - self.nanosecond()).to_int64()
  Duration::of(seconds~, nanoseconds~)
}

///|
/// Returns the exact elapsed duration since another datetime.
pub fn ZonedDateTime::since(
  self : ZonedDateTime,
  other : ZonedDateTime,
) -> Duration raise Error {
  other.until(self)
}

///|
/// Shifts this datetime's instant by whole seconds plus a nanosecond
/// offset that may be out of range, normalizing the two before converting
/// back into a local datetime. Without the normalization, a duration that
/// makes the nanosecond-of-second carry (or borrow) across a second
/// boundary would be rejected as an invalid datetime.
fn ZonedDateTime::shift_instant(
  self : ZonedDateTime,
  seconds : Int64,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  let mut total_seconds = checked_add_int64(self.to_unix_second(), seconds)
  let mut nanos = self.nanosecond().to_int64() + nanoseconds
  total_seconds = checked_add_int64(
    total_seconds,
    nanos / nanoseconds_per_second,
  )
  nanos = nanos % nanoseconds_per_second
  if nanos < 0L {
    total_seconds = checked_add_int64(total_seconds, -1L)
    nanos += nanoseconds_per_second
  }
  ZonedDateTime::from_unix_second(
    total_seconds,
    nanosecond=nanos.to_int(),
    zone=self.zone,
  )
}

///|
/// Resolves the offset for a local (wall-clock) datetime in a zone.
///
/// A zone's offset can itself vary by instant (DST), but only the local
/// time is known up front — so the true instant isn't known until the
/// offset is, and the offset isn't known until the instant is. This
/// iterates: treat the local time as a first-guess instant to look up an
/// offset, use that offset to compute a real candidate instant, then
/// re-check the offset at that instant, repeating until it stops
/// changing. This converges in at most a couple of iterations for any
/// zone whose offset doesn't change by more than it changes in total
/// (true of every real-world zone).
///
/// The previous implementation took exactly one such guess and never
/// rechecked it, so any datetime within one offset-change's distance of a
/// DST transition could resolve to the wrong offset (and therefore the
/// wrong instant). This does not add real IANA/tzdata transition tables —
/// it only fixes how an offset is resolved once `zone.lookup_offset` can
/// answer that question correctly.
fn create_from_plain(datetime : PlainDateTime, zone : Zone) -> ZonedDateTime {
  let local_secs = datetime.to_unix_second()
  let mut offset = zone.lookup_offset(local_secs)
  for i = 0; i < 3; i = i + 1 {
    let candidate_instant = local_secs - offset.seconds().to_int64()
    let next_offset = zone.lookup_offset(candidate_instant)
    if next_offset == offset {
      break
    }
    offset = next_offset
  }
  { datetime, zone, offset, }
}

///|
#deprecated
pub extend ZonedDateTime with Debug::{to_repr}

///|
#deprecated
pub extend ZonedDateTime with Show::{output}

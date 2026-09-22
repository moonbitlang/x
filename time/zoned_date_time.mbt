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
/// By default, local construction chooses the earlier instant in an overlap
/// and moves forward across a gap. Edits retain a still-valid offset.
struct ZonedDateTime {
  datetime : PlainDateTime
  zone : Zone
  offset : ZoneOffset
} derive(Debug)

///|
/// How to resolve a local clock reading when a zone's offset changes.
/// Unambiguous readings are unchanged by every policy.
pub(all) enum Disambiguation {
  /// Choose the earlier instant in an overlap; shift forward across a gap.
  Compatible
  /// Choose the earlier instant in an overlap; shift backward across a gap.
  Earlier
  /// Choose the later instant in an overlap; shift forward across a gap.
  Later
  /// Raise an error for either an overlap or a gap.
  Reject
} derive(Eq, Debug)

///|
/// How field edits interpret the original UTC offset, following Temporal.
/// An accepted offset determines the instant before `Disambiguation` is used.
/// When resolving from the zone instead, `Disambiguation` handles gaps and overlaps.
pub(all) enum OffsetPolicy {
  /// Use the original offset if valid for the new local time; otherwise resolve
  /// from the zone using the disambiguation policy. This is the default.
  Prefer
  /// Ignore the original offset and resolve from the zone using disambiguation.
  Ignore
  /// Compute the instant with the original offset even if it is no longer valid.
  /// Then project into the zone; the resulting local fields and offset can change.
  Use
  /// Use the original offset if valid; otherwise raise an error, even when the
  /// new local time is unambiguous. This is distinct from Disambiguation::Reject.
  Reject
} derive(Eq, Debug)

///|
#deprecated
pub extend OffsetPolicy with Eq::{equal, not_equal}

///|
#deprecated
pub extend OffsetPolicy with Debug::{to_repr}

///|
#deprecated
pub extend Disambiguation with Eq::{equal, not_equal}

///|
#deprecated
pub extend Disambiguation with Debug::{to_repr}

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute, second and a time zone.
/// The default time zone is UTC+0.
/// Uses the same disambiguation policy as `ZonedDateTime::of`.
pub fn date_time(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
  disambiguation? : Disambiguation = Compatible,
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
    disambiguation~,
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
/// `Compatible` (the default) chooses the earlier instant in an overlap and
/// shifts forward across a gap. `Earlier` shifts backward across a gap;
/// `Later` chooses the later instant in an overlap. `Reject` raises an error
/// for either case. Adjustments beyond the date range remain unresolved.
pub fn ZonedDateTime::of(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
  disambiguation? : Disambiguation = Compatible,
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
  create_from_plain(datetime, zone, disambiguation~)
}

///|
/// Creates a ZonedDateTime from a local calendar date and clock reading.
/// The default time zone is UTC+0.
/// `Compatible` (the default) chooses the earlier instant in an overlap and
/// shifts forward across a gap. `Earlier` shifts backward across a gap;
/// `Later` chooses the later instant in an overlap. `Reject` raises an error
/// for either case. Adjustments beyond the date range remain unresolved.
pub fn ZonedDateTime::from_plain(
  datetime : PlainDateTime,
  zone? : Zone = utc_zone,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(datetime, zone, disambiguation~)
}

///|
/// Creates a ZonedDateTime from a PlainDateTime and a time zone.
/// The default time zone is UTC+0.
/// When clocks move backward and a local time occurs twice, uses the first
/// occurrence. When clocks move forward and skip a local time, moves it forward
/// by the gap's duration. Adjustments beyond the date range remain unresolved.
#deprecated("Use `ZonedDateTime::from_plain` to choose a disambiguation policy")
pub fn ZonedDateTime::from_plain_datetime(
  datetime : PlainDateTime,
  zone? : Zone = utc_zone,
) -> ZonedDateTime {
  // Compatible never rejects a reading. Keep this entry point non-raising
  // while callers migrate to the constructor that supports explicit rejection.
  create_from_plain(datetime, zone) catch {
    _ =>
      { datetime, zone, offset: zone.lookup_offset(datetime.to_unix_second()), }
  }
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
  if self.zone != utc_zone {
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
pub impl Show for ZonedDateTime with fn output(
  self : ZonedDateTime,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
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
  create_from_plain(
    self.datetime.add_years(years),
    self.zone,
    preferred=Some(self.offset),
  )
}

///|
/// Adds specified months to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_months(
  self : ZonedDateTime,
  months : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.add_months(months),
    self.zone,
    preferred=Some(self.offset),
  )
}

///|
/// Adds specified weeks to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_weeks(
  self : ZonedDateTime,
  weeks : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.add_weeks(weeks),
    self.zone,
    preferred=Some(self.offset),
  )
}

///|
/// Adds specified days to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_days(
  self : ZonedDateTime,
  days : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.add_days(days),
    self.zone,
    preferred=Some(self.offset),
  )
}

///|
/// Adds elapsed hours on the instant timeline, preserving the time zone.
/// Across offset changes, 24 elapsed hours can differ from one calendar day.
pub fn ZonedDateTime::add_hours(
  self : ZonedDateTime,
  hours : Int64,
) -> ZonedDateTime raise Error {
  self.add_seconds(checked_mul_int64(hours, seconds_per_hour))
}

///|
/// Adds elapsed minutes on the instant timeline, preserving the time zone.
pub fn ZonedDateTime::add_minutes(
  self : ZonedDateTime,
  minutes : Int64,
) -> ZonedDateTime raise Error {
  self.add_seconds(checked_mul_int64(minutes, seconds_per_minute))
}

///|
/// Adds elapsed seconds on the instant timeline, preserving the time zone.
pub fn ZonedDateTime::add_seconds(
  self : ZonedDateTime,
  seconds : Int64,
) -> ZonedDateTime raise Error {
  ZonedDateTime::from_unix_second(
    checked_add_int64(self.to_unix_second(), seconds),
    nanosecond=self.nanosecond(),
    zone=self.zone,
  )
}

///|
/// Adds elapsed nanoseconds on the instant timeline, preserving the time zone.
pub fn ZonedDateTime::add_nanoseconds(
  self : ZonedDateTime,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  // Split before adding so even an Int64-sized adjustment cannot overflow
  // the fractional part. Normalize a negative remainder with a second borrow.
  let nanos = self.nanosecond().to_int64() +
    nanoseconds % nanoseconds_per_second
  let seconds = checked_add_int64(
    checked_add_int64(
      self.to_unix_second(),
      nanoseconds / nanoseconds_per_second,
    ),
    floor_div_int64(nanos, nanoseconds_per_second),
  )
  ZonedDateTime::from_unix_second(
    seconds,
    nanosecond=floor_mod_int64(nanos, nanoseconds_per_second).to_int(),
    zone=self.zone,
  )
}

///|
/// Returns a new datetime with the specified year.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_year(
  self : ZonedDateTime,
  year : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_year(year),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified month.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_month(
  self : ZonedDateTime,
  month : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_month(month),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified day of the month.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_day(
  self : ZonedDateTime,
  day : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_day(day),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified ordinal day of the year.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_ordinal(
  self : ZonedDateTime,
  ordinal : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_ordinal(ordinal),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified hour.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_hour(
  self : ZonedDateTime,
  hour : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_hour(hour),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified minute.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_minute(
  self : ZonedDateTime,
  minute : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_minute(minute),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified second.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_second(
  self : ZonedDateTime,
  second : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_second(second),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
/// Returns a new datetime with the specified nanosecond.
/// Defaults to `offset=Prefer` and `disambiguation=Compatible`: retain a valid
/// original offset; otherwise choose the earlier overlap or shift a gap forward.
pub fn ZonedDateTime::with_nanosecond(
  self : ZonedDateTime,
  nanosecond : Int,
  offset? : OffsetPolicy = Prefer,
  disambiguation? : Disambiguation = Compatible,
) -> ZonedDateTime raise Error {
  create_from_plain(
    self.datetime.with_nanosecond(nanosecond),
    self.zone,
    preferred=Some(self.offset),
    offset~,
    disambiguation~,
  )
}

///|
// Local clock readings are not UTC timestamps. Test possible offsets against
// the UTC lookup, so construction and conversion back from Unix time agree.
fn create_from_plain(
  datetime : PlainDateTime,
  zone : Zone,
  disambiguation? : Disambiguation = Compatible,
  preferred? : ZoneOffset? = None,
  offset? : OffsetPolicy = Prefer,
) -> ZonedDateTime raise Error {
  // PlainDateTime's bounded year range leaves ample Int64 headroom for offsets.
  let wall = datetime.to_unix_second()
  if offset != Ignore && preferred is Some(preferred) {
    let instant = wall - preferred.seconds().to_int64()
    if offset == Use {
      return ZonedDateTime::from_unix_second(
        instant,
        nanosecond=datetime.nanosecond(),
        zone~,
      )
    }
    let resolved = zone.lookup_offset(instant)
    if resolved.seconds() == preferred.seconds() {
      // A matching offset already selects an instant, even in an overlap.
      // Refresh its designation and DST flag from the zone at the new instant.
      return { datetime, zone, offset: resolved, }
    }
    if offset == OffsetPolicy::Reject {
      fail("Offset is not valid for local time")
    }
  }
  let future_offsets = match zone.future {
    None => []
    Some(Fixed(offset)) => [offset]
    Some(Seasonal(standard~, daylight~, ..)) => [standard, daylight]
  }
  let mut chosen : ZoneOffset? = None
  for candidate in zone.offsets.iter().concat(future_offsets.iter()) {
    let offset = zone.lookup_offset(wall - candidate.seconds().to_int64())
    if offset.seconds() != candidate.seconds() {
      continue
    }
    match chosen {
      None => chosen = Some(offset)
      Some(previous) => {
        // Several historical types may share one offset. Reject only distinct
        // valid instants, not duplicate candidates or unused historical types.
        if disambiguation == Reject && offset.seconds() != previous.seconds() {
          fail("Ambiguous local time")
        }
        // Larger offsets give earlier instants for the same clock reading.
        // Keep lookup's metadata, even when several types share an offset.
        if (disambiguation == Later && offset.seconds() < previous.seconds()) ||
          (disambiguation != Later && offset.seconds() > previous.seconds()) {
          chosen = Some(offset)
        }
      }
    }
  }
  if chosen is Some(offset) {
    return { datetime, zone, offset, }
  }
  if disambiguation == Reject {
    fail("Nonexistent local time")
  }

  // No offset maps back to this reading: locate the actual forward jump.
  // Only transitions within the allowed +/-18-hour offsets can contain it.
  // Looking at transition boundaries avoids mistaking unused historical types
  // for either side of a gap. Projected duplicate transitions are harmless:
  // lookup_offset selects the actual type before and after the whole change.
  let lower = wall - 18L * 3600L
  let upper = wall + 18L * 3600L
  let changes = []
  for (second, _) in zone.transitions {
    if second >= lower && second <= upper {
      changes.push(second)
    }
  }
  if zone.future is Some(Seasonal(standard~, daylight~, start~, end~)) {
    // Signed rule times and offsets can cross a nominal year boundary.
    for year in (datetime.year() - 1)..<=(datetime.year() + 1) {
      for
        second in [
          tzif_rule_time(start, year, standard.seconds()),
          tzif_rule_time(end, year, daylight.seconds()),
        ] {
        if second >= lower && second <= upper {
          changes.push(second)
        }
      }
    }
  }
  changes.sort()
  let mut shifted : (Int64, Int64)? = None
  for second in changes {
    let before = zone.lookup_offset(second - 1).seconds().to_int64()
    let after = zone.lookup_offset(second).seconds().to_int64()
    if wall >= second + before && wall < second + after {
      // Interpret with the opposite side's offset, accounting for intervening
      // changes. Closely spaced jumps can create overlapping wall-clock gaps;
      // choose the smallest adjustment in the requested direction.
      let instant = wall -
        (if disambiguation == Earlier { after } else { before })
      let resolved = instant + zone.lookup_offset(instant).seconds().to_int64()
      let better = if disambiguation == Earlier {
        resolved < wall &&
        (
          shifted is None ||
          (shifted is Some((_, previous)) && resolved > previous)
        )
      } else {
        resolved > wall &&
        (
          shifted is None ||
          (shifted is Some((_, previous)) && resolved < previous)
        )
      }
      if better {
        shifted = Some((instant, resolved))
      }
    }
  }
  if shifted is Some((instant, _)) {
    // The input's nanoseconds are valid and offset arithmetic fits Int64.
    // Conversion can fail only if the adjustment exceeds the date range.
    try
      ZonedDateTime::from_unix_second(
        instant,
        nanosecond=datetime.nanosecond(),
        zone~,
      )
    catch {
      _ => ()
    } noraise {
      value => return value
    }
  }
  // TODO: Decide how to handle an unrepresentable gap adjustment, such as
  // 9999-12-31 23:30 moving into year 10000. Keep the historical result until
  // that policy is settled, without introducing an error or a panic here.
  let offset = zone.lookup_offset(wall)
  { datetime, zone, offset, }
}

///|
#deprecated
pub extend ZonedDateTime with Debug::{to_repr}

///|
#deprecated
pub extend ZonedDateTime with Show::{output}

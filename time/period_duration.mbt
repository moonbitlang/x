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
/// A combination of a calendar-based [Period] (years/months/days) and an
/// exact-length [Duration] (hours/minutes/seconds/nanoseconds).
///
/// This is useful whenever an amount of time needs to preserve calendar
/// units instead of resolving them to an exact length up front — most
/// notably as the result of subtracting one `PlainDateTime` from another,
/// where e.g. "1 month" should stay "1 month" rather than being flattened
/// into a fixed number of seconds (months and years don't have a fixed
/// length, so that flattening would be lossy/surprising).
///
/// `PeriodDuration` intentionally does not implement `Compare`: whether
/// `P1M` is longer or shorter than `PT700H` depends on which month it is
/// and isn't answerable without a reference date, so no total order is
/// provided. Use `estimated_compare` if you need a rough ordering under an
/// explicit fixed-length assumption.
struct PeriodDuration {
  period : Period
  duration : Duration
} derive(Eq, Debug)

///|
/// Creates a PeriodDuration from a period and a duration.
pub fn PeriodDuration::of(
  period? : Period = Period::zero(),
  duration? : Duration = Duration::zero(),
) -> PeriodDuration {
  { period, duration, }
}

///|
/// Returns a zero length period-duration.
pub fn PeriodDuration::zero() -> PeriodDuration {
  { period: Period::zero(), duration: Duration::zero(), }
}

///|
/// Creates a PeriodDuration from a period alone.
pub fn PeriodDuration::from_period(period : Period) -> PeriodDuration {
  PeriodDuration::of(period~)
}

///|
/// Creates a PeriodDuration from a duration alone.
pub fn PeriodDuration::from_duration(duration : Duration) -> PeriodDuration {
  PeriodDuration::of(duration~)
}

///|
#deprecated("Use `PeriodDuration::from_str` instead")
pub fn PeriodDuration::from_string(str : String) -> PeriodDuration raise Error {
  PeriodDuration::parse_str(str)
}

///|
/// Parses an ISO 8601 duration string of the form
/// `P[n]Y[n]M[n]DT[n]H[n]M[n].[n]S`. Either the date part (before `T`) or
/// the time part (`T` onwards) may be omitted, but at least one component
/// must be present.
pub fn PeriodDuration::parse_str(
  str : StringView,
) -> PeriodDuration raise Error {
  guard str is [.. "P", ..] else { fail(invalid_period_duration_err) }
  let mut years = 0
  let mut months = 0
  let mut days = 0
  let mut hours = 0L
  let mut minutes = 0L
  let mut seconds = 0L
  let mut nanoseconds = 0L
  let mut in_time_part = false
  let mut saw_any_field = false
  let mut saw_time_field = false
  let buf = StringBuilder(size_hint=0)
  for i = 1; i < str.length(); i = i + 1 {
    match str.code_unit_at(i) {
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '.' | '-' =>
        buf.write_char(str.code_unit_at(i).unsafe_to_char())
      'T' => in_time_part = true
      'Y' => {
        if in_time_part {
          fail(invalid_period_duration_err)
        }
        years = @string.from_str(buf.to_string())
        buf.reset()
        saw_any_field = true
      }
      'M' =>
        if in_time_part {
          minutes = @string.from_str(buf.to_string())
          buf.reset()
          saw_any_field = true
          saw_time_field = true
        } else {
          months = @string.from_str(buf.to_string())
          buf.reset()
          saw_any_field = true
        }
      'D' => {
        if in_time_part {
          fail(invalid_period_duration_err)
        }
        days = @string.from_str(buf.to_string())
        buf.reset()
        saw_any_field = true
      }
      'H' => {
        if !in_time_part {
          fail(invalid_period_duration_err)
        }
        hours = @string.from_str(buf.to_string())
        buf.reset()
        saw_any_field = true
        saw_time_field = true
      }
      'S' => {
        if !in_time_part {
          fail(invalid_period_duration_err)
        }
        let s = buf.to_string()
        if s.is_empty() {
          fail(invalid_period_duration_err)
        }
        let splits = s.split(".")
        let secs_str = match splits.next() {
          Some(part) => part
          None => fail(invalid_period_duration_err)
        }
        let nanos_str = splits.next()
        match splits.next() {
          Some(_) => fail(invalid_period_duration_err)
          None => ()
        }
        // The sign lives on the whole-seconds field, but `-0.5` has to stay
        // negative too, so look at the sign textually instead of at the
        // parsed (possibly zero) whole-second value.
        let negative = secs_str.length() > 0 && secs_str.code_unit_at(0) == '-'
        if !secs_str.is_empty() {
          seconds = @string.from_str(secs_str)
        }
        match nanos_str {
          Some(nanos) if !nanos.is_empty() => {
            let mut nanos_str = add_suffix_zero(nanos, 9)
            if negative {
              nanos_str = "-" + nanos_str
            }
            nanoseconds = @string.from_str(nanos_str)
          }
          _ => ()
        }
        // Reject an empty seconds field, e.g. "PT.S".
        if secs_str.is_empty() && nanoseconds == 0L {
          fail(invalid_period_duration_err)
        }
        buf.reset()
        saw_any_field = true
        saw_time_field = true
      }
      _ => fail(invalid_period_duration_err)
    }
  }
  // Reject bare "P" / "PT" with no fields at all, malformed input that
  // parsed without error only because every field defaults to zero, and
  // trailing garbage such as a number without a designator ("P1Y2").
  if !saw_any_field || !buf.to_string().is_empty() {
    fail(invalid_period_duration_err)
  }
  // Reject a "T" that is not followed by any time component, e.g. "P1YT".
  if in_time_part && !saw_time_field {
    fail(invalid_period_duration_err)
  }
  let period = Period::of(years~, months~, days~)
  let duration = Duration::of(hours~, minutes~, seconds~, nanoseconds~)
  PeriodDuration::of(period~, duration~)
}

///|
pub impl @string.FromStr for PeriodDuration with fn from_str(str) {
  PeriodDuration::parse_str(str)
}

///|
/// Returns a string representation of this period-duration using ISO 8601
/// representation, e.g. `P1Y2M3DT4H5M6S`.
pub fn PeriodDuration::to_string(self : PeriodDuration) -> String {
  if self.is_zero() {
    return "P0D"
  }
  let buf = StringBuilder(size_hint=0)
  buf.write_char('P')
  if self.period.years() != 0 {
    buf.write_string(self.period.years().to_string())
    buf.write_char('Y')
  }
  if self.period.months() != 0 {
    buf.write_string(self.period.months().to_string())
    buf.write_char('M')
  }
  if self.period.days() != 0 {
    buf.write_string(self.period.days().to_string())
    buf.write_char('D')
  }
  if !self.duration.is_zero() {
    buf.write_char('T')
    let total_secs = self.duration.seconds()
    let hours = total_secs / seconds_per_hour
    let minutes = total_secs % seconds_per_hour / seconds_per_minute
    let seconds = total_secs % seconds_per_minute
    let nanos_of_seconds = seconds * nanoseconds_per_second +
      self.duration.nanoseconds().to_int64()
    let secs = (nanos_of_seconds / nanoseconds_per_second).abs()
    let nanos = (nanos_of_seconds % nanoseconds_per_second).abs()
    if hours != 0L {
      buf.write_string(hours.to_string())
      buf.write_char('H')
    }
    if minutes != 0L {
      buf.write_string(minutes.to_string())
      buf.write_char('M')
    }
    if secs != 0L || nanos > 0L {
      if nanos_of_seconds < 0L {
        buf.write_char('-')
      }
      buf.write_string(secs.to_string())
      if nanos > 0L {
        buf.write_string(format_nanos(nanos).to_string())
      }
      buf.write_char('S')
    }
  }
  buf.to_string()
}

///|
pub impl Show for PeriodDuration with fn output(
  self : PeriodDuration,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Hash for PeriodDuration with fn hash_combine(
  self : PeriodDuration,
  hasher : Hasher,
) -> Unit {
  hasher.combine(self.period)
  hasher.combine(self.duration)
}

///|
pub impl ToJson for PeriodDuration with fn to_json(self : PeriodDuration) -> Json {
  Json(self.to_string())
}

///|
pub impl FromJson for PeriodDuration with fn from_json(json, path) -> PeriodDuration raise {
  guard json is Json::String(str) else {
    raise @json.JsonDecodeError(
      (path, "PeriodDuration: expected string \{Repr(json)}"),
    )
  }
  let period_duration : PeriodDuration = @string.FromStr::from_str(str) catch {
    _e =>
      raise @json.JsonDecodeError(
        (path, "PeriodDuration: Invalid ISO8601 string \{str}"),
      )
  }
  period_duration
}

///|
/// Returns the calendar part of this period-duration.
pub fn PeriodDuration::period(self : PeriodDuration) -> Period {
  self.period
}

///|
/// Returns the exact-length part of this period-duration.
pub fn PeriodDuration::duration(self : PeriodDuration) -> Duration {
  self.duration
}

///|
/// Returns a new period-duration with the specified period, keeping the
/// same duration.
pub fn PeriodDuration::with_period(
  self : PeriodDuration,
  period : Period,
) -> PeriodDuration {
  if period == self.period {
    self
  } else {
    { ..self, period, }
  }
}

///|
/// Returns a new period-duration with the specified duration, keeping the
/// same period.
pub fn PeriodDuration::with_duration(
  self : PeriodDuration,
  duration : Duration,
) -> PeriodDuration {
  if duration == self.duration {
    self
  } else {
    { ..self, duration, }
  }
}

///|
/// Adds another period-duration to this one, adding periods to periods and
/// durations to durations independently (no normalization between the two).
pub fn PeriodDuration::add(
  self : PeriodDuration,
  other : PeriodDuration,
) -> PeriodDuration raise Error {
  PeriodDuration::of(
    period=self.period.add_period(other.period),
    duration=self.duration.add_duration(other.duration),
  )
}

///|
pub fn PeriodDuration::op_add(
  self : PeriodDuration,
  other : PeriodDuration,
) -> PeriodDuration raise Error {
  self.add(other)
}

///|
/// Subtracts another period-duration from this one, subtracting periods
/// from periods and durations from durations independently.
pub fn PeriodDuration::subtract(
  self : PeriodDuration,
  other : PeriodDuration,
) -> PeriodDuration raise Error {
  PeriodDuration::of(
    period=self.period.subtract_period(other.period),
    duration=self.duration.subtract_duration(other.duration),
  )
}

///|
pub fn PeriodDuration::op_sub(
  self : PeriodDuration,
  other : PeriodDuration,
) -> PeriodDuration raise Error {
  self.subtract(other)
}

///|
/// Returns a new period-duration with both the period and the duration
/// negated.
pub fn PeriodDuration::negated(
  self : PeriodDuration,
) -> PeriodDuration raise Error {
  PeriodDuration::of(
    period=self.period.negated(),
    duration=self.duration.negated(),
  )
}

///|
pub fn PeriodDuration::op_neg(
  self : PeriodDuration,
) -> PeriodDuration raise Error {
  self.negated()
}

///|
/// Checks if this period-duration is zero length in both parts.
pub fn PeriodDuration::is_zero(self : PeriodDuration) -> Bool {
  self.period.is_zero() && self.duration.is_zero()
}

///|
/// Estimates a total length in seconds using fixed-length assumptions for
/// calendar units (a 30-day month and a 12-month year of 360 days, so that
/// equivalent periods such as `P1Y` and `P12M` estimate the same length),
/// for use cases such as sorting where an approximate, explicitly-labeled
/// ordering is acceptable. Sub-second precision is ignored. This is NOT a
/// substitute for resolving a period against a real calendar and reference
/// date, and two period-durations with the same estimate may still
/// represent different actual lengths once resolved.
pub fn PeriodDuration::estimated_compare(
  self : PeriodDuration,
  other : PeriodDuration,
) -> Int {
  fn estimate_secs(pd : PeriodDuration) -> Int64 {
    let p = pd.period
    let calendar_days = p.to_total_months() * 30L + p.days().to_int64()
    calendar_days * seconds_per_day + pd.duration.seconds()
  }

  let a = estimate_secs(self)
  let b = estimate_secs(other)
  if a > b {
    1
  } else if a < b {
    -1
  } else {
    0
  }
}

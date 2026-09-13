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
/// An amount of time with nanosecond precision.
struct Duration {
  secs : Int64
  nanos : Int
} derive(Debug)

///|
/// Creates a Duration from hours, minutes, seconds and nanoseconds.
pub fn Duration::of(
  hours? : Int64 = 0L,
  minutes? : Int64 = 0L,
  seconds? : Int64 = 0L,
  nanoseconds? : Int64 = 0L,
) -> Duration raise Error {
  let hours_sec = checked_mul_int64(hours, seconds_per_hour)
  let minutes_sec = checked_mul_int64(minutes, seconds_per_minute)
  let mut secs = checked_add_int64(
    checked_add_int64(hours_sec, minutes_sec),
    seconds,
  )
  let nanos = (nanoseconds % nanoseconds_per_second).to_int()
  secs += nanoseconds / nanoseconds_per_second
  { secs, nanos, }
}

///|
fn create(secs : Int64, nanos : Int) -> Duration raise Error {
  if nanos < min_nanosecond || nanos > max_nanosecond {
    fail(invalid_duration_err)
  }
  { secs, nanos, }
}

///|
/// Returns a zero length duration.
pub fn Duration::zero() -> Duration {
  { secs: 0L, nanos: 0, }
}

///|
/// Creates a Duration from a number of whole hours.
pub fn Duration::from_hours(hours : Int64) -> Duration raise Error {
  Duration::of(hours~)
}

///|
/// Creates a Duration from a number of whole minutes.
pub fn Duration::from_minutes(minutes : Int64) -> Duration raise Error {
  Duration::of(minutes~)
}

///|
/// Creates a Duration from a number of whole seconds.
pub fn Duration::from_seconds(seconds : Int64) -> Duration raise Error {
  Duration::of(seconds~)
}

///|
/// Creates a Duration from a number of milliseconds.
pub fn Duration::from_millis(milliseconds : Int64) -> Duration raise Error {
  let secs = milliseconds / millis_per_second
  let nanos = milliseconds % millis_per_second * nanoseconds_per_milli
  Duration::of(seconds=secs, nanoseconds=nanos)
}

///|
/// Creates a Duration from a number of nanoseconds.
pub fn Duration::from_nanoseconds(nanoseconds : Int64) -> Duration raise Error {
  Duration::of(nanoseconds~)
}

///|
/// Parses a ISO 8601 format string like `PT[n]H[n]M[n].[n]S`.
#deprecated("Use `Duration::from_str` instead")
pub fn Duration::from_string(str : String) -> Duration raise Error {
  Duration::parse_str(str)
}

///|
fn Duration::parse_str(str : StringView) -> Duration raise Error {
  guard str is [.. "PT", ..] else { fail(invalid_duration_err) }
  let mut hours = 0L
  let mut minutes = 0L
  let mut seconds = 0L
  let mut nanoseconds = 0L
  let buf = StringBuilder(size_hint=0)
  for i = 2; i < str.length(); i = i + 1 {
    match str.code_unit_at(i) {
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '.' | '-' =>
        buf.write_char(str.code_unit_at(i).unsafe_to_char())
      'H' => {
        hours = @string.from_str(buf.to_string())
        buf.reset()
      }
      'M' => {
        minutes = @string.from_str(buf.to_string())
        buf.reset()
      }
      'S' => {
        let s = buf.to_string()
        if s.is_empty() {
          fail(invalid_duration_err)
        }
        let splits = s.split(".")
        let secs_str = match splits.next() {
          Some(part) => part
          None => fail(invalid_duration_err)
        }
        let nanos_str = splits.next()
        match splits.next() {
          Some(_) => fail(invalid_duration_err)
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
        // Nothing may follow the seconds component.
        if i != str.length() - 1 {
          fail(invalid_duration_err)
        }
        break
      }
      _ => fail(invalid_duration_err)
    }
  }
  Duration::of(hours~, minutes~, seconds~, nanoseconds~)
}

///|
pub impl @string.FromStr for Duration with fn from_str(str) {
  Duration::parse_str(str)
}

///|
/// Returns a string representation of this duration using ISO 8601 representation.
pub fn Duration::to_string(self : Duration) -> String {
  if self.is_zero() {
    return "PT0S"
  }
  let buf = StringBuilder(size_hint=0)
  buf.write_string("PT")
  let total_secs = self.secs
  let hours = total_secs / seconds_per_hour
  let minutes = total_secs % seconds_per_hour / seconds_per_minute
  let seconds = total_secs % seconds_per_minute
  let nanos_of_seconds = seconds * nanoseconds_per_second +
    self.nanos.to_int64()
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
  buf.to_string()
}

///|
pub impl Show for Duration with fn output(self : Duration, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Hash for Duration with fn hash_combine(
  self : Duration,
  hasher : Hasher,
) -> Unit {
  let (secs, nanos) = normalized(self)
  hasher.combine(secs)
  hasher.combine(nanos)
}

///|
pub impl ToJson for Duration with fn to_json(self : Duration) -> Json {
  Json(self.to_string())
}

///|
pub impl FromJson for Duration with fn from_json(json, path) -> Duration raise {
  guard json is Json::String(str) else {
    raise @json.JsonDecodeError(
      (path, "Duration: expected string \{Repr(json)}"),
    )
  }
  let duration : Duration = @string.FromStr::from_str(str) catch {
    _e =>
      raise @json.JsonDecodeError(
        (path, "Duration: Invalid ISO8601 duration string \{str}"),
      )
  }
  duration
}

///|
pub impl Eq for Duration with fn equal(self : Duration, other : Duration) -> Bool {
  Compare::compare(self, other) == 0
}

///|
pub impl Compare for Duration with fn compare(self : Duration, other : Duration) -> Int {
  let (self_secs, self_nanos) = normalized(self)
  let (other_secs, other_nanos) = normalized(other)
  if self_secs > other_secs {
    1
  } else if self_secs < other_secs {
    -1
  } else if self_nanos > other_nanos {
    1
  } else if self_nanos < other_nanos {
    -1
  } else {
    0
  }
}

///|
/// Returns the number of seconds in this duration.
pub fn Duration::seconds(self : Duration) -> Int64 {
  self.secs
}

///|
/// Returns the number of nanoseconds in this duration.
pub fn Duration::nanoseconds(self : Duration) -> Int {
  self.nanos
}

///|
/// Returns the canonical `(secs, nanos)` split of this duration, with
/// `nanos` in `[0, nanoseconds_per_second)`. The same length can be stored
/// with different splits depending on how it was built — e.g.
/// `Duration::of(nanoseconds=-1L)` is `(0, -1)` while
/// `Duration::of(seconds=-1L, nanoseconds=999_999_999L)` is `(-1, 999_999_999)`
/// — so comparison, hashing and sign checks normalize first.
fn normalized(d : Duration) -> (Int64, Int) {
  if d.nanos >= 0 || d.secs == @int64.MIN_VALUE {
    // `secs == Int64::MIN_VALUE` has no canonical form that fits in Int64,
    // so leave it as is rather than wrapping on the borrow.
    (d.secs, d.nanos)
  } else {
    (d.secs - 1L, d.nanos + nanoseconds_per_second.to_int())
  }
}

///|
/// Checks if this duration is zero length.
pub fn Duration::is_zero(self : Duration) -> Bool {
  self.secs == 0L && self.nanos == 0
}

///|
/// Checks if this duration is negative.
pub fn Duration::is_neg(self : Duration) -> Bool {
  Compare::compare(self, Duration::zero()) < 0
}

///|
/// Checks if this duration is strictly positive.
pub fn Duration::is_positive(self : Duration) -> Bool {
  self.secs > 0L || (self.secs == 0L && self.nanos > 0)
}

///|
/// Adds specified hours to this duration, and returns a new duration.
pub fn Duration::add_hours(
  self : Duration,
  hours : Int64,
) -> Duration raise Error {
  if hours == 0L {
    return self
  }
  let secs = checked_add_int64(
    self.secs,
    checked_mul_int64(hours, seconds_per_hour),
  )
  { ..self, secs, }
}

///|
/// Adds specified minutes to this duration, and returns a new duration.
pub fn Duration::add_minutes(
  self : Duration,
  minutes : Int64,
) -> Duration raise Error {
  if minutes == 0L {
    return self
  }
  let secs = checked_add_int64(
    self.secs,
    checked_mul_int64(minutes, seconds_per_minute),
  )
  { ..self, secs, }
}

///|
/// Adds specified seconds to this duration, and returns a new duration.
pub fn Duration::add_seconds(
  self : Duration,
  seconds : Int64,
) -> Duration raise Error {
  if seconds == 0L {
    return self
  }
  let secs = checked_add_int64(self.secs, seconds)
  { ..self, secs, }
}

///|
/// Adds specified nanoseconds to this duration, and returns a new duration.
pub fn Duration::add_nanoseconds(
  self : Duration,
  nanoseconds : Int64,
) -> Duration raise Error {
  if nanoseconds == 0L {
    return self
  }
  let mut secs = checked_add_int64(
    self.secs,
    nanoseconds / nanoseconds_per_second,
  )
  let mut nanos = self.nanos.to_int64() + nanoseconds % nanoseconds_per_second
  if nanos < 0L {
    secs = checked_add_int64(secs, -1L)
    nanos += nanoseconds_per_second
  } else if nanos >= nanoseconds_per_second {
    secs = checked_add_int64(secs, 1L)
    nanos -= nanoseconds_per_second
  }
  create(secs, nanos.to_int())
}

///|
/// Adds other duration to this duration, and returns a new duration.
pub fn Duration::add_duration(
  self : Duration,
  other : Duration,
) -> Duration raise Error {
  if other.is_zero() {
    return self
  }
  let mut nanos = self.nanos.to_int64() + other.nanos.to_int64()
  let mut secs = checked_add_int64(self.secs, other.secs)
  secs = checked_add_int64(secs, nanos / nanoseconds_per_second)
  nanos = nanos % nanoseconds_per_second
  if nanos < 0L {
    secs -= 1L
    nanos += nanoseconds_per_second
  }
  create(secs, nanos.to_int())
}

///|
pub fn Duration::op_add(
  self : Duration,
  other : Duration,
) -> Duration raise Error {
  self.add_duration(other)
}

///|
/// Subtracts specified hours from this duration, and returns a new duration.
pub fn Duration::subtract_hours(
  self : Duration,
  hours : Int64,
) -> Duration raise Error {
  self.add_hours(-hours)
}

///|
/// Subtracts specified minutes from this duration, and returns a new duration.
pub fn Duration::subtract_minutes(
  self : Duration,
  minutes : Int64,
) -> Duration raise Error {
  self.add_minutes(-minutes)
}

///|
/// Subtracts specified seconds from this duration, and returns a new duration.
pub fn Duration::subtract_seconds(
  self : Duration,
  seconds : Int64,
) -> Duration raise Error {
  self.add_seconds(-seconds)
}

///|
/// Subtracts specified nanoseconds from this duration, and returns a new duration.
pub fn Duration::subtract_nanoseconds(
  self : Duration,
  nanoseconds : Int64,
) -> Duration raise Error {
  self.add_nanoseconds(-nanoseconds)
}

///|
/// Subtracts other duration from this duration, and returns a new duration.
pub fn Duration::subtract_duration(
  self : Duration,
  other : Duration,
) -> Duration raise Error {
  self.add_duration(other.negated())
}

///|
pub fn Duration::op_sub(
  self : Duration,
  other : Duration,
) -> Duration raise Error {
  self.subtract_duration(other)
}

///|
/// Returns a new duration with the same length but opposite sign.
pub fn Duration::negated(self : Duration) -> Duration raise Error {
  if self.is_zero() {
    return self
  }
  let (secs, nanos) = normalized(self)
  if nanos == 0 {
    if secs == @int64.MIN_VALUE {
      int64_overflow_err()
    }
    create(-secs, 0)
  } else if secs == @int64.MIN_VALUE && nanos < 0 {
    // The negation lies below the representable canonical range.
    int64_overflow_err()
  } else {
    // `secs == Int64::MIN_VALUE` is only reachable here when `nanos > 0`,
    // and `-(secs + 1)` is representable for it.
    create(-(secs + 1L), nanoseconds_per_second.to_int() - nanos)
  }
}

///|
pub fn Duration::op_neg(self : Duration) -> Duration raise Error {
  self.negated()
}

///|
/// Returns a new duration with a positive length, keeping the magnitude of
/// this duration.
pub fn Duration::abs(self : Duration) -> Duration raise Error {
  if self.is_neg() {
    self.negated()
  } else {
    self
  }
}

///|
/// Returns a new duration that is this duration scaled by the given factor.
pub fn Duration::multiplied_by(
  self : Duration,
  factor : Int64,
) -> Duration raise Error {
  if factor == 0L {
    return Duration::zero()
  }
  if factor == 1L {
    return self
  }
  let total_nanos = self.to_nanoseconds_checked()
  let scaled = checked_mul_int64(total_nanos, factor)
  let secs = scaled / nanoseconds_per_second
  let nanos = (scaled % nanoseconds_per_second).to_int()
  create(secs, nanos)
}

///|
/// Returns a new duration that is this duration divided by the given
/// divisor. Truncates towards zero, as with integer division.
pub fn Duration::divided_by(
  self : Duration,
  divisor : Int64,
) -> Duration raise Error {
  if divisor == 0L {
    fail(invalid_duration_err)
  }
  if divisor == 1L {
    return self
  }
  let total_nanos = self.to_nanoseconds_checked()
  let scaled = total_nanos / divisor
  let secs = scaled / nanoseconds_per_second
  let nanos = (scaled % nanoseconds_per_second).to_int()
  create(secs, nanos)
}

///|
/// Returns the smaller of the two durations.
pub fn Duration::min(self : Duration, other : Duration) -> Duration {
  if Compare::compare(self, other) <= 0 {
    self
  } else {
    other
  }
}

///|
/// Returns the larger of the two durations.
pub fn Duration::max(self : Duration, other : Duration) -> Duration {
  if Compare::compare(self, other) >= 0 {
    self
  } else {
    other
  }
}

///|
/// Returns a new duration with the specified amount of seconds.
pub fn Duration::with_seconds(self : Duration, seconds : Int64) -> Duration {
  if seconds == self.secs {
    return self
  }
  { secs: seconds, nanos: self.nanos, }
}

///|
/// Returns a new duration with the specified nanosecond of second.
pub fn Duration::with_nanoseconds(
  self : Duration,
  nanoseconds : Int,
) -> Duration raise Error {
  if nanoseconds == self.nanos {
    return self
  }
  create(self.secs, nanoseconds)
}

///|
/// Converts this duration to the total length in nanoseconds.
pub fn Duration::to_nanoseconds(self : Duration) -> Int64 {
  self.secs * nanoseconds_per_second + self.nanos.to_int64()
}

///|
/// Converts this duration to the total length in nanoseconds, raising when
/// the length does not fit in an `Int64` (durations longer than ~292 years),
/// instead of wrapping around.
fn Duration::to_nanoseconds_checked(self : Duration) -> Int64 raise Error {
  let max_secs = @int64.MAX_VALUE / nanoseconds_per_second
  let min_secs = @int64.MIN_VALUE / nanoseconds_per_second
  let max_nanos = @int64.MAX_VALUE % nanoseconds_per_second
  let min_nanos = @int64.MIN_VALUE % nanoseconds_per_second
  if self.secs > max_secs ||
    self.secs < min_secs ||
    (self.secs == max_secs && self.nanos.to_int64() > max_nanos) ||
    (self.secs == min_secs && self.nanos.to_int64() < min_nanos) {
    int64_overflow_err()
  }
  self.to_nanoseconds()
}

///|
/// Converts this duration to the total length in milliseconds, truncating
/// any remaining nanoseconds.
pub fn Duration::to_millis(self : Duration) -> Int64 {
  self.secs * millis_per_second + self.nanos.to_int64() / nanoseconds_per_milli
}

///|
/// Returns the whole number of hours in this duration, truncating any
/// remaining minutes, seconds and nanoseconds.
pub fn Duration::to_hours(self : Duration) -> Int64 {
  let (secs, _) = normalized(self)
  secs / seconds_per_hour
}

///|
/// Returns the whole number of minutes in this duration, truncating any
/// remaining seconds and nanoseconds.
pub fn Duration::to_minutes(self : Duration) -> Int64 {
  let (secs, _) = normalized(self)
  secs / seconds_per_minute
}
// *****************************
// * internal helper functions *
// *****************************

///|
let millis_per_second = 1000L

///|
let nanoseconds_per_milli = 1_000_000L

///|
#deprecated
pub extend Duration with Eq::{not_equal, equal}

///|
#deprecated
pub extend Duration with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
pub extend Duration with Debug::{to_repr}

///|
#deprecated
pub extend Duration with @string.FromStr::{from_str}

///|
#deprecated
pub extend Duration with Show::{output}

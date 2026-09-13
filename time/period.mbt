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
/// An amount of time representing by years, months and days in the ISO-8601 calendar system.
struct Period {
  years : Int
  months : Int
  days : Int
} derive(Debug)

///|
/// Creates a Period from years, months, and days.
pub fn Period::of(
  years? : Int = 0,
  months? : Int = 0,
  days? : Int = 0,
) -> Period {
  { years, months, days, }
}

///|
/// Returns a zero length period.
pub fn Period::zero() -> Period {
  { years: 0, months: 0, days: 0, }
}

///|
/// Creates a Period from a number of years.
pub fn Period::from_years(years : Int) -> Period {
  Period::of(years~)
}

///|
/// Creates a Period from a number of months.
pub fn Period::from_months(months : Int) -> Period {
  Period::of(months~)
}

///|
/// Creates a Period from a number of weeks, expressed as a number of days.
pub fn Period::from_weeks(weeks : Int) -> Period raise Error {
  Period::of(days=checked_mul_int(weeks, 7))
}

///|
/// Creates a Period from a number of days.
pub fn Period::from_days(days : Int) -> Period {
  Period::of(days~)
}

///|
#deprecated("Use `Period::from_str` instead")
pub fn Period::from_string(str : String) -> Period raise Error {
  Period::parse_str(str)
}

///|
/// Parses a ISO 8601 format string like `P[n]Y[n]M[n]D`.
pub fn Period::parse_str(str : StringView) -> Period raise Error {
  // TODO: better parsing impl
  guard str.length() > 0 && str.code_unit_at(0) == 'P' else {
    fail(invalid_period_err)
  }
  let buf = StringBuilder(size_hint=0)
  let mut years = 0
  let mut months = 0
  let mut days = 0
  for i = 1; i < str.length(); i = i + 1 {
    match str.code_unit_at(i) {
      '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '-' =>
        buf.write_char(str.code_unit_at(i).unsafe_to_char())
      'Y' => {
        years = @string.from_str(buf.to_string())
        buf.reset()
      }
      'M' => {
        months = @string.from_str(buf.to_string())
        buf.reset()
      }
      'D' => {
        days = @string.from_str(buf.to_string())
        buf.reset()
        break
      }
      _ => fail(invalid_period_err)
    }
  }
  Period::of(years~, months~, days~)
}

///|
pub impl @string.FromStr for Period with fn from_str(str) {
  Period::parse_str(str)
}

///|
/// Returns a string representation of this period using ISO 8601 representation.
pub fn Period::to_string(self : Period) -> String {
  if self.is_zero() {
    return "P0D"
  }
  let buf = StringBuilder(size_hint=0)
  buf.write_char('P')
  if self.years != 0 {
    buf.write_string(self.years.to_string())
    buf.write_char('Y')
  }
  if self.months != 0 {
    buf.write_string(self.months.to_string())
    buf.write_char('M')
  }
  if self.days != 0 {
    buf.write_string(self.days.to_string())
    buf.write_char('D')
  }
  buf.to_string()
}

///|
pub impl Show for Period with fn output(self : Period, logger : &Logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Hash for Period with fn hash_combine(self : Period, hasher : Hasher) -> Unit {
  hasher.combine(self.years)
  hasher.combine(self.months)
  hasher.combine(self.days)
}

///|
pub impl Eq for Period with fn equal(self : Period, other : Period) -> Bool {
  Compare::compare(self, other) == 0
}

///|
pub impl Compare for Period with fn compare(self : Period, other : Period) -> Int {
  if self.years > other.years {
    1
  } else if self.years < other.years {
    -1
  } else if self.months > other.months {
    1
  } else if self.months < other.months {
    -1
  } else if self.days > other.days {
    1
  } else if self.days < other.days {
    -1
  } else {
    0
  }
}

///|
pub impl ToJson for Period with fn to_json(self : Period) -> Json {
  Json(self.to_string())
}

///|
pub impl FromJson for Period with fn from_json(json, path) -> Period raise {
  guard json is Json::String(str) else {
    raise @json.JsonDecodeError((path, "Period: expected string \{Repr(json)}"))
  }
  let period : Period = @string.FromStr::from_str(str) catch {
    _e =>
      raise @json.JsonDecodeError(
        (path, "Period: Invalid ISO8601 string \{str}"),
      )
  }
  period
}

///|
/// Returns the number of years in this duration.
pub fn Period::years(self : Period) -> Int {
  self.years
}

///|
/// Returns the number of months in this duration.
pub fn Period::months(self : Period) -> Int {
  self.months
}

///|
/// Returns the number of days in this duration.
pub fn Period::days(self : Period) -> Int {
  self.days
}

///|
/// Adds specified years to this period, and returns a new period.
pub fn Period::add_years(self : Period, years : Int) -> Period raise Error {
  if years == 0 {
    return self
  }
  let new_years = checked_add_int(self.years, years)
  Period::of(years=new_years, months=self.months, days=self.days)
}

///|
/// Adds specified weeks to this period, and returns a new period.
pub fn Period::add_weeks(self : Period, weeks : Int) -> Period raise Error {
  if weeks == 0 {
    return self
  }
  let new_days = checked_add_int(self.days, checked_mul_int(weeks, 7))
  Period::of(years=self.years, months=self.months, days=new_days)
}

///|
/// Adds specified months to this period, and returns a new period.
pub fn Period::add_months(self : Period, months : Int) -> Period raise Error {
  if months == 0 {
    return self
  }
  let new_months = checked_add_int(self.months, months)
  Period::of(years=self.years, months=new_months, days=self.days)
}

///|
/// Adds specified days to this period, and returns a new period.
pub fn Period::add_days(self : Period, days : Int) -> Period raise Error {
  if days == 0 {
    return self
  }
  let new_days = checked_add_int(self.days, days)
  Period::of(years=self.years, months=self.months, days=new_days)
}

///|
/// Adds other period to this period, and returns a new period.
pub fn Period::add_period(self : Period, other : Period) -> Period raise Error {
  if other.is_zero() {
    return self
  }
  self
  .add_years(other.years())
  .add_months(other.months())
  .add_days(other.days())
}

///|
pub fn Period::op_add(self : Period, other : Period) -> Period raise Error {
  self.add_period(other)
}

///|
/// Subtracts specified years from this period, and returns a new period.
pub fn Period::subtract_years(self : Period, years : Int) -> Period raise Error {
  self.add_years(-years)
}

///|
/// Subtracts specified months from this period, and returns a new period.
pub fn Period::subtract_months(
  self : Period,
  months : Int,
) -> Period raise Error {
  self.add_months(-months)
}

///|
/// Subtracts specified weeks from this period, and returns a new period.
pub fn Period::subtract_weeks(self : Period, weeks : Int) -> Period raise Error {
  self.add_weeks(-weeks)
}

///|
/// Subtracts specified days from this period, and returns a new period.
pub fn Period::subtract_days(self : Period, days : Int) -> Period raise Error {
  self.add_days(-days)
}

///|
/// Subtracts other period from this period, and returns a new period.
pub fn Period::subtract_period(
  self : Period,
  other : Period,
) -> Period raise Error {
  self.add_period(other.negated())
}

///|
pub fn Period::op_sub(self : Period, other : Period) -> Period raise Error {
  self.subtract_period(other)
}

///|
/// Returns a new period with all elements in this period multiplied by the specified value.
pub fn Period::multiply(self : Period, n : Int) -> Period raise Error {
  if n == 0 {
    return Period::zero()
  }
  if self.is_zero() || n == 1 {
    return self
  }
  let years = checked_mul_int(self.years, n)
  let months = checked_mul_int(self.months, n)
  let days = checked_mul_int(self.days, n)
  Period::of(years~, months~, days~)
}

///|
/// Returns a new period with all elements in this period negated.
pub fn Period::negated(self : Period) -> Period raise Error {
  self.multiply(-1)
}

///|
/// Returns a new period with a positive sign on every element, keeping the
/// magnitude of this period. Assumes the period's elements share the same
/// sign, as is the case for any period produced by this library.
pub fn Period::abs(self : Period) -> Period raise Error {
  if self.is_neg() {
    self.negated()
  } else {
    self
  }
}

///|
/// Returns a new period with the specified amount of years.
pub fn Period::with_years(self : Period, years : Int) -> Period {
  if years == self.years {
    self
  } else {
    Period::of(years~, months=self.months, days=self.days)
  }
}

///|
/// Returns a new period with the specified amount of months.
pub fn Period::with_months(self : Period, months : Int) -> Period {
  if months == self.months {
    self
  } else {
    Period::of(years=self.years, months~, days=self.days)
  }
}

///|
/// Returns a new period with the specified amount of days.
pub fn Period::with_days(self : Period, days : Int) -> Period {
  if days == self.days {
    self
  } else {
    Period::of(years=self.years, months=self.months, days~)
  }
}

///|
/// Checks if this period is zero length.
pub fn Period::is_zero(self : Period) -> Bool {
  self.years == 0 && self.months == 0 && self.days == 0
}

///|
/// Checks if this period is negative.
pub fn Period::is_neg(self : Period) -> Bool {
  self.years < 0 || self.months < 0 || self.days < 0
}

///|
/// Checks if this period is strictly positive.
pub fn Period::is_positive(self : Period) -> Bool {
  !self.is_zero() && !self.is_neg()
}

///|
/// Returns the total number of months in this period (years * 12 + months),
/// ignoring the days element.
pub fn Period::to_total_months(self : Period) -> Int64 {
  self.years.to_int64() * 12L + self.months.to_int64()
}

///|
/// Returns an equivalent period with the years and months fields normalized,
/// carrying every whole 12-month group in `months` into `years`. Both fields
/// end up with the same sign as the total number of months. The `days`
/// field is left untouched, since a variable number of days per month means
/// days cannot be safely folded into months without a reference date.
pub fn Period::normalized(self : Period) -> Period {
  let total_months = self.to_total_months()
  let years = total_months / 12L
  let months = total_months % 12L
  Period::of(years=years.to_int(), months=months.to_int(), days=self.days)
}

///|
#deprecated
pub extend Period with Debug::{to_repr}

///|
#deprecated
pub extend Period with Show::{output}

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
test "of" {
  inspect(@time.PlainDateTime::of(2000, 1, 1), content="2000-01-01T00:00:00")
  inspect(
    @time.PlainDateTime::of(
      2000,
      1,
      1,
      hour=1,
      minute=2,
      second=3,
      nanosecond=400,
    ),
    content="2000-01-01T01:02:03.0000004",
  )
  inspect(@time.PlainDateTime::of(0, 1, 1), content="0000-01-01T00:00:00")
  inspect(
    @time.PlainDateTime::of(
      9999,
      12,
      31,
      hour=23,
      minute=59,
      second=59,
      nanosecond=999_999_999,
    ),
    content="9999-12-31T23:59:59.999999999",
  )
  inspect(
    @time.PlainDateTime::of(
      -9999,
      12,
      31,
      hour=23,
      minute=59,
      second=59,
      nanosecond=999_999_999,
    ),
    content="-9999-12-31T23:59:59.999999999",
  )
}

///|
test "from_unix_second" {
  inspect(
    @time.PlainDateTime::from_unix_second(1714227729L, 1000, @time.utc_offset),
    content="2024-04-27T14:22:09.000001",
  )
  inspect(
    @time.PlainDateTime::from_unix_second(
      1714227729L,
      1000,
      @time.ZoneOffset::from_seconds(8 * 60 * 60),
    ),
    content="2024-04-27T22:22:09.000001",
  )
  @test.assert_raise(() => {
    @time.PlainDateTime::from_unix_second(
      1714227729L, 1_000_000_000, @time.utc_offset,
    )
  })
}

///|
test "from_str" {
  inspect(
    (@string.FromStr::from_str("0000-01-01T00:00:00") : @time.PlainDateTime),
    content="0000-01-01T00:00:00",
  )
  inspect(
    (@string.FromStr::from_str("9999-12-31T23:59:59") : @time.PlainDateTime),
    content="9999-12-31T23:59:59",
  )
  inspect(
    (@string.FromStr::from_str("-9999-12-31T23:59:59") : @time.PlainDateTime),
    content="-9999-12-31T23:59:59",
  )
  inspect(
    (
      @string.FromStr::from_str("2000-01-01T00:00:00.12345") :
      @time.PlainDateTime),
    content="2000-01-01T00:00:00.12345",
  )
  @test.assert_raise(() => {
    (@string.FromStr::from_str("9999-12-31T23:59:60") : @time.PlainDateTime)
  })
  @test.assert_raise(() => {
    (@string.FromStr::from_str("10000-12-31T23:59:60") : @time.PlainDateTime)
  })
  @test.assert_raise(() => {
    (@string.FromStr::from_str("2000-01-01 00:00:00") : @time.PlainDateTime)
  })
  @test.assert_raise(() => {
    (@string.FromStr::from_str("2000-01-01") : @time.PlainDateTime)
  })
  @test.assert_raise(() => {
    (@string.FromStr::from_str("00:00:00") : @time.PlainDateTime)
  })
}

///|
test "getters" {
  let d = @time.PlainDateTime::of(
    2000,
    2,
    29,
    hour=1,
    minute=10,
    second=30,
    nanosecond=1000,
  )
  inspect(d.era(), content="CE")
  inspect(d.era_year(), content="2000")
  inspect(d.year(), content="2000")
  inspect(d.month(), content="2")
  inspect(d.day(), content="29")
  inspect(d.weekday(), content="Tuesday")
  inspect(d.ordinal(), content="60")
  inspect(d.days_in_year(), content="366")
  inspect(d.days_in_month(), content="29")
  inspect(d.days_in_week(), content="7")
  inspect(d.months_in_year(), content="12")
  inspect(d.hour(), content="1")
  inspect(d.minute(), content="10")
  inspect(d.second(), content="30")
  inspect(d.nanosecond(), content="1000")
}

///|
test "in_leap_year" {
  inspect(@time.PlainDateTime::of(2000, 1, 1).in_leap_year(), content="true")
  inspect(@time.PlainDateTime::of(2001, 1, 1).in_leap_year(), content="false")
}

///|
test "add_years" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.add_years(0L), content="2000-02-29T00:00:00")
  inspect(d.add_years(1L), content="2001-02-28T00:00:00")
  inspect(d.add_years(7999L), content="9999-02-28T00:00:00")
  @test.assert_raise(() => d.add_years(8000L))
  inspect(d.add_years(-11999L), content="-9999-02-28T00:00:00")
  @test.assert_raise(() => d.add_years(-12000L))
}

///|
test "add_months" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.add_months(0L), content="2000-02-29T00:00:00")
  inspect(d.add_months(1L), content="2000-03-29T00:00:00")
  inspect(d.add_months(12L * 7999L), content="9999-02-28T00:00:00")
  @test.assert_raise(() => d.add_months(12L * 8000L))
  inspect(d.add_months(12L * -11999L), content="-9999-02-28T00:00:00")
  @test.assert_raise(() => d.add_months(12L * -12000L))
}

///|
test "add_weeks" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.add_weeks(0L), content="2000-02-29T00:00:00")
  inspect(d.add_weeks(1L), content="2000-03-07T00:00:00")
  inspect(d.add_weeks(-1L), content="2000-02-22T00:00:00")
  inspect(d.add_weeks(3L), content="2000-03-21T00:00:00")
  inspect(d.add_weeks(-3L), content="2000-02-08T00:00:00")
  @test.assert_raise(() => d.add_weeks(@int64.MAX_VALUE))
  @test.assert_raise(() => d.add_weeks(@int64.MIN_VALUE))
}

///|
test "add_days" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.add_days(0L), content="2000-02-29T00:00:00")
  inspect(d.add_days(1L), content="2000-03-01T00:00:00")
  inspect(d.add_days(-1L), content="2000-02-28T00:00:00")
  inspect(d.add_days(365L), content="2001-02-28T00:00:00")
  inspect(d.add_days(-365L), content="1999-03-01T00:00:00")
  @test.assert_raise(() => d.add_days(@int64.MAX_VALUE))
  @test.assert_raise(() => d.add_days(@int64.MIN_VALUE))
}

///|
test "add_period" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(
    d.add_period(@time.Period::of(years=1)),
    content="2001-02-28T00:00:00",
  )
  inspect(
    d.add_period(@time.Period::of(months=1)),
    content="2000-03-29T00:00:00",
  )
  inspect(d.add_period(@time.Period::of(days=1)), content="2000-03-01T00:00:00")
  inspect(
    d.add_period(@time.Period::of(years=1, months=1, days=1)),
    content="2001-03-30T00:00:00",
  )
}

///|
test "add_hours" {
  let d = @time.PlainDateTime::of(0, 1, 1)
  inspect(d.add_hours(0L), content="0000-01-01T00:00:00")
  inspect(d.add_hours(1L), content="0000-01-01T01:00:00")
  inspect(d.add_hours(24L), content="0000-01-02T00:00:00")
  inspect(d.add_hours(24L * 30L), content="0000-01-31T00:00:00")
  inspect(d.add_hours(24L * 366L), content="0001-01-01T00:00:00")
}

///|
test "add_minutes" {
  let d = @time.PlainDateTime::of(0, 1, 1)
  inspect(d.add_minutes(0L), content="0000-01-01T00:00:00")
  inspect(d.add_minutes(1L), content="0000-01-01T00:01:00")
  inspect(d.add_minutes(60L), content="0000-01-01T01:00:00")
  inspect(d.add_minutes(24L * 60L), content="0000-01-02T00:00:00")
  inspect(d.add_minutes(24L * 60L * 366L), content="0001-01-01T00:00:00")
}

///|
test "add_seconds" {
  let d = @time.PlainDateTime::of(0, 1, 1)
  inspect(d.add_seconds(0L), content="0000-01-01T00:00:00")
  inspect(d.add_seconds(1L), content="0000-01-01T00:00:01")
  inspect(d.add_seconds(60L), content="0000-01-01T00:01:00")
  inspect(d.add_seconds(60L * 60L), content="0000-01-01T01:00:00")
  inspect(d.add_seconds(24L * 60L * 60L), content="0000-01-02T00:00:00")
  inspect(d.add_seconds(24L * 60L * 60L * 366L), content="0001-01-01T00:00:00")
}

///|
test "add_duration" {
  let d = @time.PlainDateTime::of(0, 1, 1)
  inspect(d.add_duration(@time.Duration::zero()), content="0000-01-01T00:00:00")
  inspect(
    d.add_duration(@time.Duration::of(hours=1L)),
    content="0000-01-01T01:00:00",
  )
  inspect(
    d.add_duration(@time.Duration::of(minutes=1L)),
    content="0000-01-01T00:01:00",
  )
  inspect(
    d.add_duration(@time.Duration::of(seconds=1L)),
    content="0000-01-01T00:00:01",
  )
  inspect(
    d.add_duration(@time.Duration::of(nanoseconds=100L)),
    content="0000-01-01T00:00:00.0000001",
  )
  inspect(
    d.add_duration(
      @time.Duration::of(hours=1L, minutes=10L, seconds=30L, nanoseconds=1000L),
    ),
    content="0000-01-01T01:10:30.000001",
  )
}

///|
test "with_year" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.with_year(2000), content="2000-02-29T00:00:00")
  inspect(d.with_year(2001), content="2001-02-28T00:00:00")
  inspect(d.with_year(2008), content="2008-02-29T00:00:00")
  inspect(d.with_year(0), content="0000-02-29T00:00:00")
  inspect(d.with_year(9999), content="9999-02-28T00:00:00")
  inspect(d.with_year(-9999), content="-9999-02-28T00:00:00")
  @test.assert_raise(() => d.with_year(10000))
  @test.assert_raise(() => d.with_year(-10000))
}

///|
test "with_month" {
  let d = @time.PlainDateTime::of(2000, 1, 31)
  inspect(d.with_month(1), content="2000-01-31T00:00:00")
  inspect(d.with_month(2), content="2000-02-29T00:00:00")
  inspect(d.with_month(4), content="2000-04-30T00:00:00")
  @test.assert_raise(() => d.with_month(0))
  @test.assert_raise(() => d.with_month(13))
}

///|
test "with_day" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.with_day(29), content="2000-02-29T00:00:00")
  inspect(d.with_day(1), content="2000-02-01T00:00:00")
  @test.assert_raise(() => d.with_day(0))
  @test.assert_raise(() => d.with_day(30))
}

///|
test "with_ordinal" {
  let d = @time.PlainDateTime::of(2000, 2, 29)
  inspect(d.with_ordinal(1), content="2000-01-01T00:00:00")
  inspect(d.with_ordinal(366), content="2000-12-31T00:00:00")
  @test.assert_raise(() => d.with_ordinal(0))
  @test.assert_raise(() => d.with_ordinal(367))
}

///|
test "with_hour" {
  let d = @time.PlainDateTime::of(2000, 1, 1, hour=1)
  inspect(d.with_hour(1), content="2000-01-01T01:00:00")
  inspect(d.with_hour(10), content="2000-01-01T10:00:00")
  inspect(d.with_hour(0), content="2000-01-01T00:00:00")
  inspect(d.with_hour(24), content="2000-01-01T24:00:00")
  @test.assert_raise(() => d.with_hour(-1))
  @test.assert_raise(() => d.with_hour(25))
}

///|
test "with_minute" {
  let d = @time.PlainDateTime::of(2000, 1, 1, minute=20)
  inspect(d.with_minute(20), content="2000-01-01T00:20:00")
  inspect(d.with_minute(10), content="2000-01-01T00:10:00")
  inspect(d.with_minute(0), content="2000-01-01T00:00:00")
  inspect(d.with_minute(59), content="2000-01-01T00:59:00")
  @test.assert_raise(() => d.with_minute(-1))
  @test.assert_raise(() => d.with_minute(60))
}

///|
test "with_second" {
  let d = @time.PlainDateTime::of(2000, 1, 1, second=30)
  inspect(d.with_second(30), content="2000-01-01T00:00:30")
  inspect(d.with_second(10), content="2000-01-01T00:00:10")
  inspect(d.with_second(0), content="2000-01-01T00:00:00")
  inspect(d.with_second(59), content="2000-01-01T00:00:59")
  @test.assert_raise(() => d.with_second(-1))
  @test.assert_raise(() => d.with_second(60))
}

///|
test "with_nanosecond" {
  let d = @time.PlainDateTime::of(2000, 1, 1, nanosecond=400)
  inspect(d.with_nanosecond(400), content="2000-01-01T00:00:00.0000004")
  inspect(d.with_nanosecond(100), content="2000-01-01T00:00:00.0000001")
  inspect(d.with_nanosecond(0), content="2000-01-01T00:00:00")
  inspect(
    d.with_nanosecond(999_999_999),
    content="2000-01-01T00:00:00.999999999",
  )
  @test.assert_raise(() => d.with_nanosecond(-1))
  @test.assert_raise(() => d.with_nanosecond(1_000_000_000))
}

///|
test "to_plain_date and to_plain_time" {
  let d = @time.PlainDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    nanosecond=400,
  )
  inspect(d.to_plain_date(), content="2000-01-01")
  inspect(d.to_plain_time(), content="01:02:03.0000004")
}

///|

///|
test "plain_date_time_json_roundtrip" {
  let dt = @time.PlainDateTime::of(2024, 1, 2, hour=3, minute=4, second=5)
  let back : @time.PlainDateTime = @json.from_json(ToJson::to_json(dt))
  inspect(back, content="2024-01-02T03:04:05")
}

///|
test "from_str errors" {
  for s in ["2000-01-01T00:00:00T", "T00:00:00", "2000-01-01T00:00:00 "] {
    @test.assert_raise(() => {
      (@string.FromStr::from_str(s) : @time.PlainDateTime)
    })
  }
}

///|
test "compare" {
  let base = @time.PlainDateTime::of(2000, 1, 1)
  let one_second_later = @time.PlainDateTime::of(2000, 1, 1, second=1)
  inspect(base == @time.PlainDateTime::of(2000, 1, 1), content="true")
  inspect(base == one_second_later, content="false")
  inspect(
    Compare::compare(base, @time.PlainDateTime::of(2000, 1, 1)),
    content="0",
  )
  // The same date orders by the time of day, in both directions.
  inspect(Compare::compare(base, one_second_later), content="-1")
  inspect(Compare::compare(one_second_later, base), content="1")
  inspect(base < one_second_later, content="true")
  inspect(base > one_second_later, content="false")
  inspect(one_second_later > base, content="true")
  inspect(one_second_later < base, content="false")
  // Sub-second differences are ordered as well.
  let one_nanosecond_later = @time.PlainDateTime::of(2000, 1, 1, nanosecond=1)
  inspect(base < one_nanosecond_later, content="true")
  inspect(Compare::compare(base, one_nanosecond_later), content="-1")
  inspect(Compare::compare(one_nanosecond_later, base), content="1")
  // The date part dominates the time part.
  let next_day = @time.PlainDateTime::of(2000, 1, 2)
  inspect(base < next_day, content="true")
  inspect(next_day > one_second_later, content="true")
  inspect(Compare::compare(base, next_day), content="-1")
  inspect(Compare::compare(next_day, base), content="1")
}

///|
fn plain_dt(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
) -> @time.PlainDateTime raise {
  @time.PlainDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
  )
}

///|
test "millisecond and microsecond" {
  let dt = plain_dt(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    nanosecond=123_456_789,
  )
  inspect(dt.nanosecond(), content="123456789")
  inspect(dt.millisecond(), content="123")
  inspect(dt.microsecond(), content="456")
  inspect(plain_dt(2000, 1, 1).millisecond(), content="0")
  inspect(plain_dt(2000, 1, 1, nanosecond=1).millisecond(), content="0")
  inspect(plain_dt(2000, 1, 1, nanosecond=1).microsecond(), content="0")
  inspect(
    plain_dt(2000, 1, 1, nanosecond=999_999_999).microsecond(),
    content="999",
  )
}

///|
test "month_code, day_of_week, week_of_year and year_of_week" {
  let dt = plain_dt(2021, 1, 1, hour=1)
  inspect(dt.month_code(), content="M01")
  inspect(dt.day_of_week(), content="5")
  inspect(dt.week_of_year(), content="53")
  inspect(dt.year_of_week(), content="2020")
  inspect(plain_dt(2000, 12, 31).month_code(), content="M12")
  inspect(plain_dt(2024, 1, 1).day_of_week(), content="1")
  inspect(plain_dt(2024, 1, 1).weekday(), content="Monday")
}

///|
test "equals, min and max" {
  let a = plain_dt(2000, 1, 1)
  let b = plain_dt(2000, 1, 1, nanosecond=1)
  inspect(a.equals(a), content="true")
  inspect(a.equals(b), content="false")
  inspect(@time.PlainDateTime::min(a, b), content="2000-01-01T00:00:00")
  inspect(
    @time.PlainDateTime::max(a, b),
    content="2000-01-01T00:00:00.000000001",
  )
  inspect(@time.PlainDateTime::min(b, a), content="2000-01-01T00:00:00")
}

///|
test "subtract_years, months, weeks and days" {
  let dt = plain_dt(2000, 3, 31, hour=1, minute=2, second=3)
  inspect(dt.subtract_years(1L), content="1999-03-31T01:02:03")
  inspect(dt.subtract_months(1L), content="2000-02-29T01:02:03")
  inspect(dt.subtract_weeks(1L), content="2000-03-24T01:02:03")
  inspect(dt.subtract_days(1L), content="2000-03-30T01:02:03")
  inspect(dt.subtract_days(0L), content="2000-03-31T01:02:03")
}

///|
test "subtract_hours, minutes, seconds and nanoseconds" {
  let dt = plain_dt(2000, 1, 1)
  inspect(dt.subtract_hours(1L), content="1999-12-31T23:00:00")
  inspect(dt.subtract_minutes(1L), content="1999-12-31T23:59:00")
  inspect(dt.subtract_seconds(1L), content="1999-12-31T23:59:59")
  inspect(dt.subtract_nanoseconds(1L), content="1999-12-31T23:59:59.999999999")
  inspect(dt.subtract_hours(0L), content="2000-01-01T00:00:00")
  inspect(dt.subtract_hours(-1L), content="2000-01-01T01:00:00")
}

///|
test "subtract_duration" {
  let dt = plain_dt(2000, 1, 1, hour=12)
  inspect(
    dt.subtract_duration(@time.Duration::of(hours=1L)),
    content="2000-01-01T11:00:00",
  )
  inspect(
    dt.subtract_duration(@time.Duration::of(nanoseconds=1L)),
    content="2000-01-01T11:59:59.999999999",
  )
  inspect(
    dt.subtract_duration(@time.Duration::zero()),
    content="2000-01-01T12:00:00",
  )
}

///|
test "add_period_duration" {
  let start = plain_dt(2000, 1, 31)
  let pd = @time.PeriodDuration::of(
    period=@time.Period::of(months=1),
    duration=@time.Duration::of(hours=1L),
  )
  // The calendar period is applied first (clamping Jan 31 to Feb 29), then
  // the exact duration; applying the duration first would give
  // 2000-03-01T01:00:00 instead.
  inspect(start.add_period_duration(pd), content="2000-02-29T01:00:00")
  inspect(
    start.add_period_duration(@time.PeriodDuration::zero()),
    content="2000-01-31T00:00:00",
  )
  inspect(
    start.add_period_duration(
      @time.PeriodDuration::from_period(@time.Period::of(days=1)),
    ),
    content="2000-02-01T00:00:00",
  )
}

///|
test "subtract_period_duration" {
  let start = plain_dt(2000, 1, 15, hour=10)
  let pd = @time.PeriodDuration::of(
    period=@time.Period::of(months=1),
    duration=@time.Duration::of(hours=1L),
  )
  let later = start.add_period_duration(pd)
  inspect(later, content="2000-02-15T11:00:00")
  inspect(later.subtract_period_duration(pd), content="2000-01-15T10:00:00")
  inspect(
    later.subtract_period_duration(@time.PeriodDuration::zero()),
    content="2000-02-15T11:00:00",
  )
}

///|
test "modify_with" {
  let dt = plain_dt(2000, 1, 15, hour=10, minute=20, second=30, nanosecond=400)
  inspect(dt.modify_with(year=2024), content="2024-01-15T10:20:30.0000004")
  inspect(
    dt.modify_with(month=2, day=29),
    content="2000-02-29T10:20:30.0000004",
  )
  inspect(
    dt.modify_with(hour=0, minute=0, second=0, nanosecond=0),
    content="2000-01-15T00:00:00",
  )
  inspect(dt.modify_with(), content="2000-01-15T10:20:30.0000004")
  @test.assert_raise(() => dt.modify_with(month=2, day=30))
  @test.assert_raise(() => dt.modify_with(hour=25))
}

///|
test "until and since" {
  let a = plain_dt(2000, 1, 1)
  let b = plain_dt(2000, 1, 1, hour=1, minute=2, second=3)
  inspect(a.until(b), content="PT1H2M3S")
  inspect(b.until(a), content="PT-1H-2M-3S")
  inspect(a.since(b), content="PT-1H-2M-3S")
  inspect(b.since(a), content="PT1H2M3S")
  inspect(a.until(a), content="PT0S")
  // Crosses day boundaries.
  inspect(plain_dt(2000, 1, 1).until(plain_dt(2000, 1, 2)), content="PT24H")
  inspect(plain_dt(2000, 1, 2).until(plain_dt(2000, 1, 1)), content="PT-24H")
  inspect(
    plain_dt(2000, 1, 1).until(
      plain_dt(1999, 12, 31, hour=23, minute=59, second=59),
    ),
    content="PT-1S",
  )
  // Sub-second precision is preserved.
  inspect(
    plain_dt(2000, 1, 1, nanosecond=1).until(plain_dt(2000, 1, 1, nanosecond=2)),
    content="PT0.000000001S",
  )
}

///|
test "until across centuries" {
  let a = plain_dt(2000, 1, 1)
  let b = plain_dt(2400, 1, 1)
  let d = a.until(b)
  let days = b.to_plain_date().to_unix_day() - a.to_plain_date().to_unix_day()
  inspect(d.seconds() == days * 86400L, content="true")
  inspect(d.nanoseconds(), content="0")
  inspect(d > @time.Duration::zero(), content="true")
  inspect(b.since(a) == d, content="true")
}

///|
test "plain_date_time_hash" {
  let a = plain_dt(2000, 1, 1, hour=1)
  let b = plain_dt(2000, 1, 1, hour=1)
  let c = plain_dt(2000, 1, 1, hour=2)
  inspect(hash_of(a) == hash_of(b), content="true")
  inspect(hash_of(a) == hash_of(c), content="false")
}

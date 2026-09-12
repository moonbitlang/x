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
test "date_time" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  inspect(
    @time.date_time(2000, 1, 1, hour=10, minute=20, second=30, zone~),
    content="2000-01-01T10:20:30+08:00[Asia/Shanghai]",
  )
}

///|
test "unix" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  inspect(
    @time.unix(1714227729L, nanosecond=1000, zone~),
    content="2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]",
  )
}

///|
test "of" {
  inspect(
    @time.ZonedDateTime::of(2000, 1, 1, hour=1, minute=2, second=3),
    content="2000-01-01T01:02:03Z",
  )
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  inspect(
    @time.ZonedDateTime::of(2000, 1, 1, hour=1, minute=2, second=3, zone~),
    content="2000-01-01T01:02:03+08:00[Asia/Shanghai]",
  )
}

///|
test "from_plain_datetime" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let datetime = @time.PlainDateTime::of(2000, 1, 1)
  inspect(
    @time.ZonedDateTime::from_plain_datetime(datetime, zone~),
    content="2000-01-01T00:00:00+08:00[Asia/Shanghai]",
  )
}

///|
test "from_unix_second" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  inspect(
    @time.ZonedDateTime::from_unix_second(0L),
    content="1970-01-01T00:00:00Z",
  )
  inspect(
    @time.ZonedDateTime::from_unix_second(60L * 60L, nanosecond=1000),
    content="1970-01-01T01:00:00.000001Z",
  )
  inspect(
    @time.ZonedDateTime::from_unix_second(0L, zone~),
    content="1970-01-01T08:00:00+08:00[Asia/Shanghai]",
  )
}

///|
test "to_unix_second" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  inspect(@time.ZonedDateTime::of(1970, 1, 1).to_unix_second(), content="0")
  inspect(
    @time.ZonedDateTime::of(1970, 1, 1, zone~).to_unix_second(),
    content="-28800",
  )
}

///|
test "conversions" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.to_unix_second(), content="946659723")
  inspect(zdt.to_plain_date(), content="2000-01-01")
  inspect(zdt.to_plain_time(), content="01:02:03")
  inspect(zdt.to_plain_date_time(), content="2000-01-01T01:02:03")
}

///|
test "getters" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.era(), content="CE")
  inspect(zdt.era_year(), content="2000")
  inspect(zdt.month(), content="1")
  inspect(zdt.day(), content="1")
  inspect(zdt.weekday(), content="Saturday")
  inspect(zdt.ordinal(), content="1")
  inspect(zdt.days_in_month(), content="31")
  inspect(zdt.days_in_week(), content="7")
  inspect(zdt.days_in_year(), content="366")
  inspect(zdt.months_in_year(), content="12")
  inspect(zdt.in_leap_year(), content="true")
  inspect(zdt.hour(), content="1")
  inspect(zdt.minute(), content="2")
  inspect(zdt.second(), content="3")
  inspect(zdt.nanosecond(), content="0")
  inspect(zdt.zone(), content="Asia/Shanghai")
  inspect(zdt.offset(), content="+08:00")
}

///|
test "add_years" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.add_years(1L), content="2001-01-01T01:02:03+08:00[Asia/Shanghai]")
}

///|
test "add_months" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.add_months(1L),
    content="2000-02-01T01:02:03+08:00[Asia/Shanghai]",
  )
}

///|
test "add_weeks" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.add_weeks(1L), content="2000-01-08T01:02:03+08:00[Asia/Shanghai]")
}

///|
test "add_days" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.add_days(1L), content="2000-01-02T01:02:03+08:00[Asia/Shanghai]")
}

///|
test "add_hours" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.add_hours(1L), content="2000-01-01T02:02:03+08:00[Asia/Shanghai]")
}

///|
test "add_minutes" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.add_minutes(1L),
    content="2000-01-01T01:03:03+08:00[Asia/Shanghai]",
  )
}

///|
test "add_seconds" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.add_seconds(1L),
    content="2000-01-01T01:02:04+08:00[Asia/Shanghai]",
  )
}

///|
test "add_nanoseconds" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.add_nanoseconds(1000L),
    content="2000-01-01T01:02:03.000001+08:00[Asia/Shanghai]",
  )
}

///|
test "with_year" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.with_year(2024),
    content="2024-01-01T01:02:03+08:00[Asia/Shanghai]",
  )
}

///|
test "with_month" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.with_month(2), content="2000-02-01T01:02:03+08:00[Asia/Shanghai]")
}

///|
test "with_day" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.with_day(31), content="2000-01-31T01:02:03+08:00[Asia/Shanghai]")
}

///|
test "with_ordinal" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.with_ordinal(365),
    content="2000-12-30T01:02:03+08:00[Asia/Shanghai]",
  )
}

///|
test "with_hour" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(zdt.with_hour(12), content="2000-01-01T12:02:03+08:00[Asia/Shanghai]")
}

///|
test "with_minute" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.with_minute(30),
    content="2000-01-01T01:30:03+08:00[Asia/Shanghai]",
  )
}

///|
test "with_second" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.with_second(30),
    content="2000-01-01T01:02:30+08:00[Asia/Shanghai]",
  )
}

///|
test "with_nanosecond" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let zdt = @time.ZonedDateTime::of(
    2000,
    1,
    1,
    hour=1,
    minute=2,
    second=3,
    zone~,
  )
  inspect(
    zdt.with_nanosecond(999_999_999),
    content="2000-01-01T01:02:03.999999999+08:00[Asia/Shanghai]",
  )
}

///|
test "parse_str" {
  inspect(
    @time.ZonedDateTime::parse_str("2000-01-01T00:00:00Z"),
    content="2000-01-01T00:00:00Z",
  )
  inspect(
    @time.ZonedDateTime::parse_str("2026-09-12T14:30:00+05:30"),
    content="2026-09-12T14:30:00+05:30",
  )
  inspect(
    @time.ZonedDateTime::parse_str(
      "2026-09-12T14:30:00-05:00[America/New_York]",
    ),
    content="2026-09-12T14:30:00-05:00[America/New_York]",
  )
  inspect(
    @time.ZonedDateTime::parse_str(
      "2026-09-12T14:30:00.123456789+05:30[Asia/Kolkata]",
    ),
    content="2026-09-12T14:30:00.123456789+05:30[Asia/Kolkata]",
  )
  // A zero offset is normalized to UTC.
  inspect(
    @time.ZonedDateTime::parse_str("2000-01-01T00:00:00+00:00"),
    content="2000-01-01T00:00:00Z",
  )
}

///|
test "parse_str roundtrip" {
  for
    s in [
      "2000-01-01T00:00:00Z", "2026-09-12T14:30:00+05:30", "2026-09-12T14:30:00-05:00[America/New_York]",
      "2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]",
    ] {
    inspect(@time.ZonedDateTime::parse_str(s).to_string(), content=s)
  }
}

///|
test "parse_str accessors" {
  let zdt = @time.ZonedDateTime::parse_str(
    "2026-09-12T14:30:45.123+05:30[Asia/Kolkata]",
  )
  inspect(zdt.year(), content="2026")
  inspect(zdt.month(), content="9")
  inspect(zdt.day(), content="12")
  inspect(zdt.hour(), content="14")
  inspect(zdt.minute(), content="30")
  inspect(zdt.second(), content="45")
  inspect(zdt.nanosecond(), content="123000000")
  inspect(zdt.zone(), content="Asia/Kolkata")
  inspect(zdt.offset(), content="+05:30")
}

///|
test "parse_str unix" {
  inspect(
    @time.ZonedDateTime::parse_str("1970-01-01T00:00:00Z").to_unix_second(),
    content="0",
  )
  inspect(
    @time.ZonedDateTime::parse_str("1970-01-01T08:00:00+08:00").to_unix_second(),
    content="0",
  )
  inspect(
    @time.ZonedDateTime::parse_str("1970-01-01T00:00:00-05:30").to_unix_second(),
    content="19800",
  )
}

///|
test "parse_str errors" {
  let invalid : Array[String] = [
    "", "2000-01-01T00:00:00", "2000-01-01T00:00:00+05", "2000-01-01T00:00:00+05:3",
    "2000-01-01T00:00:00+05:30junk", "2000-01-01T00:00:00+05:30[Bad", "2000-01-01T00:00:00+05:30[]",
    "2000-01-01T00:00:00+05:30[Asia/Kolkata]extra", "2000-01-01T00:00:00.Z+05:30",
    "2000-01-01T00:00:00.1234567890+05:30", "2000-01-01 00:00:00Z", "2000-01-01T00:00:00+19:00",
    "2000-13-01T00:00:00Z",
  ]
  for s in invalid {
    @test.assert_raise(() => @time.ZonedDateTime::parse_str(s))
  }
}

///|
test "eq and compare" {
  let a = @time.ZonedDateTime::parse_str(
    "2026-09-12T14:30:00+05:30[Asia/Kolkata]",
  )
  let b = @time.ZonedDateTime::parse_str(
    "2026-09-12T14:30:00+05:30[Asia/Kolkata]",
  )
  let c = @time.ZonedDateTime::parse_str(
    "2026-09-12T14:31:00+05:30[Asia/Kolkata]",
  )
  inspect(a == b, content="true")
  inspect(a == c, content="false")
  inspect(a < c, content="true")
  inspect(c > a, content="true")
}

///|
test "zdt from_str" {
  inspect(
    (@string.FromStr::from_str("2000-01-01T00:00:00Z") : @time.ZonedDateTime),
    content="2000-01-01T00:00:00Z",
  )
  inspect(
    (
      @string.FromStr::from_str("2026-09-12T14:30:00+05:30[Asia/Kolkata]") :
      @time.ZonedDateTime),
    content="2026-09-12T14:30:00+05:30[Asia/Kolkata]",
  )
}

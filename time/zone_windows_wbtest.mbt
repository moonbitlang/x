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
// Normalized Eastern Standard Time record, in effect since 2007. The source
// and normalization of these real Windows rules are documented in testdata/README.md.
fn eastern_windows_rule() -> Recurring raise Error {
  Windows({
    standard: ZoneOffset::from_seconds(-18000, abbrev="EST"),
    daylight: ZoneOffset::from_seconds(-14400, abbrev="EDT", dst=true),
    start: MonthWeekDay(month=3, week=2, weekday=0, second=7200),
    end: MonthWeekDay(month=11, week=1, weekday=0, second=7200),
  })
}

///|
test "real Windows annual rules have exact UTC transitions" {
  let cases = [
    // Northern summer: US Eastern 2024 starts at 07:00 UTC on March 10.
    (
      eastern_windows_rule(),
      PlainDateTime::of(2024, 3, 10, hour=7),
      -18000,
      -14400,
    ),
    // Southern summer: Sydney 2024 ends at 16:00 UTC on April 6.
    (
      Recurring::Windows({
        standard: ZoneOffset::from_seconds(36000),
        daylight: ZoneOffset::from_seconds(39600, dst=true),
        start: MonthWeekDay(month=10, week=1, weekday=0, second=7200),
        end: MonthWeekDay(month=4, week=1, weekday=0, second=10800),
      }),
      PlainDateTime::of(2024, 4, 6, hour=16),
      39600,
      36000,
    ),
    // Pyongyang 2015: the year's initial +09:00 changes to +08:30 at midnight.
    (
      Recurring::Windows({
        standard: ZoneOffset::from_seconds(30600),
        daylight: ZoneOffset::from_seconds(32400, dst=true),
        start: YearBoundary,
        end: MonthWeekDay(month=8, week=2, weekday=5, second=86400),
      }),
      PlainDateTime::of(2015, 8, 14, hour=15),
      32400,
      30600,
    ),
    // Pyongyang 2018: leaving its negative daylight adjustment restores +09:00.
    (
      Recurring::Windows({
        standard: ZoneOffset::from_seconds(32400),
        daylight: ZoneOffset::from_seconds(30600, dst=true),
        start: YearBoundary,
        end: MonthWeekDay(month=5, week=1, weekday=5, second=84600),
      }),
      PlainDateTime::of(2018, 5, 4, hour=15),
      30600,
      32400,
    ),
    // Moscow 2011: last Sunday in March, with daylight time through year end.
    (
      Recurring::Windows({
        standard: ZoneOffset::from_seconds(10800),
        daylight: ZoneOffset::from_seconds(14400, dst=true),
        start: MonthWeekDay(month=3, week=5, weekday=0, second=7200),
        end: YearBoundary,
      }),
      PlainDateTime::of(2011, 3, 26, hour=23),
      10800,
      14400,
    ),
  ]
  for (rule, date, before, after) in cases {
    let instant = date.to_unix_second()
    assert_eq(rule.lookup_offset(instant - 1).seconds(), before)
    assert_eq(rule.lookup_offset(instant).seconds(), after)
    assert_true(rule.transitions_near(date.year()).contains(instant))
  }
}

///|
test "Windows recurrence uses the common local resolver" {
  let zone : Zone = {
    id: "Eastern Standard Time",
    offsets: [],
    transitions: [],
    past: None,
    future: Some((@int64.MIN_VALUE, eastern_windows_rule())),
  }
  let cases = [
    // Gap: 02:30 does not exist. Earlier moves to 01:30; compatible to 03:30.
    (3, 10, 2, Earlier, 1, -18000),
    (3, 10, 2, Compatible, 3, -14400),
    // Overlap: 01:30 occurs twice. Earlier is EDT; later is EST.
    (11, 3, 1, Earlier, 1, -14400),
    (11, 3, 1, Later, 1, -18000),
  ]
  for
    (month, day, hour, disambiguation, expected_hour, expected_offset) in cases {
    let result = ZonedDateTime::of(
      2024,
      month,
      day,
      hour~,
      minute=30,
      zone~,
      disambiguation~,
    )
    assert_eq(result.hour(), expected_hour)
    assert_eq(result.minute(), 30)
    assert_eq(result.offset.seconds(), expected_offset)
    let back = ZonedDateTime::from_unix_second(result.to_unix_second(), zone~)
    assert_eq(back.datetime, result.datetime)
  }
  for (month, day, hour) in [(3, 10, 2), (11, 3, 1)] {
    @test.assert_raise(() => {
      ZonedDateTime::of(
        2024,
        month,
        day,
        hour~,
        minute=30,
        zone~,
        disambiguation=Reject,
      )
    })
  }
}

///|
test "Windows recurrence extrapolates without materializing extra years" {
  let rule = eastern_windows_rule()
  for year in [2024, 2424] {
    assert_eq(
      rule
      .lookup_offset(PlainDateTime::of(year, 1, 15).to_unix_second())
      .seconds(),
      -18000,
    )
    assert_eq(
      rule
      .lookup_offset(PlainDateTime::of(year, 7, 15).to_unix_second())
      .seconds(),
      -14400,
    )
  }
  for instant in [@int64.MIN_VALUE, @int64.MAX_VALUE] {
    assert_eq(rule.lookup_offset(instant).seconds(), -18000)
  }
}

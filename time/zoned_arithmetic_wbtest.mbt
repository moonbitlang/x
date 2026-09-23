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
test "elapsed additions cross an overlap without adding an extra hour" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // On October 27, 2024, 03:00 CEST became 02:00 CET: 02:30 occurred twice.
  let start = ZonedDateTime::of(
    2024,
    10,
    27,
    hour=1,
    minute=30,
    nanosecond=123,
    zone~,
  )
  for
    result in [
      start.add_hours(2),
      start.add_minutes(120),
      start.add_seconds(7200),
      start.add_nanoseconds(7200000000000L),
    ] {
    debug_inspect(
      result.to_string(),
      content="\"2024-10-27T02:30:00.000000123+01:00[CET]\"",
    )
    assert_eq(result.to_unix_second() - start.to_unix_second(), 7200L)
    assert_eq(result.add_hours(-2).datetime, start.datetime)
  }
}

///|
test "negative elapsed additions cross a gap on the instant timeline" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // On March 31, 2024, 02:00 CET became 03:00 CEST: the 02:xx hour was skipped.
  let start = ZonedDateTime::of(2024, 3, 31, hour=3, minute=30, zone~)
  for
    result in [
      start.add_hours(-2),
      start.add_minutes(-120),
      start.add_seconds(-7200),
      start.add_nanoseconds(-7200000000000L),
    ] {
    debug_inspect(
      result.to_string(),
      content="\"2024-03-31T00:30:00+01:00[CET]\"",
    )
    assert_eq(result.to_unix_second() - start.to_unix_second(), -7200L)
    assert_eq(result.add_hours(2).datetime, start.datetime)
  }
}

///|
test "nanosecond carry and borrow select the offset at the resulting instant" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  let before = ZonedDateTime::of(
    2024,
    10,
    27,
    hour=2,
    minute=59,
    second=59,
    nanosecond=999999999,
    zone~,
  )
  let after = before.add_nanoseconds(1)
  debug_inspect(after.to_string(), content="\"2024-10-27T02:00:00+01:00[CET]\"")
  let back = after.add_nanoseconds(-1)
  assert_eq(back.to_unix_second(), before.to_unix_second())
  assert_eq(back.nanosecond(), before.nanosecond())
  assert_eq(back.datetime, before.datetime)
  assert_eq(back.offset, before.offset)
}

///|
test "calendar days and elapsed hours intentionally differ across transitions" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  for (month, day, hours, result_hour) in [(3, 30, 23L, 13), (10, 26, 25L, 11)] {
    let start = ZonedDateTime::of(2024, month, day, hour=12, zone~)
    let calendar = start.add_days(1)
    assert_eq(calendar.hour(), 12)
    assert_eq(calendar.to_unix_second() - start.to_unix_second(), hours * 3600)
    let elapsed = start.add_hours(24)
    assert_eq(elapsed.hour(), result_hour)
    assert_eq(elapsed.to_unix_second() - start.to_unix_second(), 86400L)
  }
}

///|
test "Pyongyang elapsed arithmetic crosses half-hour standard-offset changes" {
  let zone = Zone::from_tzif("Asia/Pyongyang", pyongyang_tzif)
  // August 14, 2015 repeats 23:30–23:59; May 4, 2018 skips 23:30–23:59.
  // Both changes are to standard time, not seasonal DST transitions.
  let overlap = ZonedDateTime::of(2015, 8, 14, hour=23, minute=45, zone~)
  let gap = ZonedDateTime::of(2018, 5, 4, hour=23, minute=15, zone~)
  debug_inspect(
    overlap.add_minutes(30).to_string(),
    content="\"2015-08-14T23:45:00+08:30[KST]\"",
  )
  debug_inspect(
    gap.add_minutes(30).to_string(),
    content="\"2018-05-05T00:15:00+09:00[KST]\"",
  )
}

///|
test "Paris arithmetic and edits continue through the TZif footer" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // This file's explicit table ends in 2037. These are projections of its
  // pinned recurring rule, not a claim about what the law will be in 2040.
  let spring = ZonedDateTime::of(2040, 3, 25, hour=1, minute=30, zone~)
  let autumn = ZonedDateTime::of(2040, 10, 28, hour=2, minute=30, zone~)
  assert_true(spring.to_unix_second() > zone.transitions.last().unwrap().0)
  debug_inspect(
    spring.add_hours(1).to_string(),
    content="\"2040-03-25T03:30:00+02:00[CEST]\"",
  )
  debug_inspect(
    autumn.add_hours(1).to_string(),
    content="\"2040-10-28T02:30:00+01:00[CET]\"",
  )
  debug_inspect(
    spring.with_hour(2).to_string(),
    content="\"2040-03-25T03:30:00+02:00[CEST]\"",
  )
  debug_inspect(
    autumn.with_minute(45, offset=Ignore, disambiguation=Later).to_string(),
    content="\"2040-10-28T02:45:00+01:00[CET]\"",
  )
}

///|
test "Pyongyang stays at UTC+9 after its 2018 offset change" {
  let zone = Zone::from_tzif("Asia/Pyongyang", pyongyang_tzif)
  for year in [2019, 2024, 2040] {
    let winter = ZonedDateTime::of(year, 1, 15, hour=12, zone~)
    let summer = winter.with_month(7, offset=Reject)
    for value in [winter, summer] {
      assert_eq(value.hour(), 12)
      assert_eq(value.offset.seconds(), 32400)
      assert_eq(value.offset.abbreviation(), "KST")
      assert_false(value.offset.is_dst())
    }
  }
}

///|
test "elapsed arithmetic handles second-sized changes" {
  // Synthetic edge case: a 28-second gap and overlap only one minute apart.
  let zone : Zone = {
    id: "Seconds",
    offsets: [utc_offset, ZoneOffset::from_seconds(28)],
    transitions: [(0L, 1), (60L, 0)],
    past: None,
    future: None,
  }
  for (instant, seconds) in [(-1L, 2L), (1L, -2L), (59L, 2L), (61L, -2L)] {
    let start = ZonedDateTime::from_unix_second(instant, nanosecond=123, zone~)
    let result = start.add_seconds(seconds)
    assert_eq(result.to_unix_second(), instant + seconds)
    assert_eq(result.nanosecond(), 123)
    assert_eq(result.offset, zone.lookup_offset(instant + seconds))
  }
}

///|
test "large nanosecond adjustments normalize without overflowing the fraction" {
  let start = ZonedDateTime::from_unix_second(0, nanosecond=500000000)
  for
    (amount, seconds, nanos) in [
      (-9223372036854775808L, -9223372037L, 645224192),
      (9223372036854775807L, 9223372037L, 354775807),
    ] {
    let result = start.add_nanoseconds(amount)
    assert_eq(result.to_unix_second(), seconds)
    assert_eq(result.nanosecond(), nanos)
  }
}

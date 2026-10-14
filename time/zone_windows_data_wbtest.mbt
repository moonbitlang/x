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
test "Windows Pyongyang snapshot agrees with TZif at its real offset changes" {
  let windows = Zone::from_windows_rules(
    "North Korea Standard Time",
    Some(2014),
    pyongyang_windows_rules,
  )
  let tzif = Zone::from_tzif("Asia/Pyongyang", pyongyang_tzif)
  for
    (year, month, day, hour, minute) in [
      (2015, 1, 1, 0, 0), // no artificial change at the annual rule boundary
      (2015, 8, 15, 0, 0), // +09:00 becomes +08:30
      (2016, 1, 1, 0, 0),
      (2018, 1, 1, 0, 0),
      (2018, 5, 4, 23, 30), // +08:30 becomes +09:00
      (2019, 1, 1, 0, 0),
    ] {
    let wall = PlainDateTime::of(year, month, day, hour~, minute~).to_unix_second()
    // Cover the complete UTC window around each local boundary, including
    // both sides of the transition at one-second resolution.
    for second in (wall - 36000L)..<(wall - 28000L) {
      assert_eq(
        windows.lookup_offset(second).seconds(),
        tzif.lookup_offset(second).seconds(),
      )
    }
  }
  // Windows calls the pre-change +09:00 in 2015 "daylight" and the +08:30
  // in 2018 "daylight". Resolve by actual offsets, independent of that label.
  for
    (year, month, day, hour, minute) in [
      (2015, 8, 14, 23, 45),
      (2018, 5, 4, 23, 45),
    ] {
    let plain = PlainDateTime::of(year, month, day, hour~, minute~)
    for disambiguation in [Compatible, Earlier, Later] {
      let actual = ZonedDateTime::from_plain(
        plain,
        zone=windows,
        disambiguation~,
      )
      let expected = ZonedDateTime::from_plain(
        plain,
        zone=tzif,
        disambiguation~,
      )
      assert_eq(actual.datetime, expected.datetime)
      assert_eq(actual.to_unix_second(), expected.to_unix_second())
    }
    @test.assert_raise(() => {
      ZonedDateTime::from_plain(plain, zone=windows, disambiguation=Reject)
    })
  }
}

///|
test "Moscow stays at UTC+4 through the 2011 and 2014 year boundaries" {
  let zone = Zone::from_windows_rules(
    "Russian Standard Time",
    Some(2010),
    moscow_windows_rules,
  )
  for year in [2012, 2014] {
    let boundary = PlainDateTime::of(year, 1, 1).to_unix_second()
    for second in (boundary - 18000L)..<(boundary + 3600L) {
      assert_eq(zone.lookup_offset(second).seconds(), 14400)
    }
  }
  // The January end marker in 2011 means DST continues through December;
  // it must not make the preceding January daylight time as well.
  assert_eq(
    zone
    .lookup_offset(PlainDateTime::of(2011, 1, 15).to_unix_second())
    .seconds(),
    10800,
  )
  assert_eq(
    zone
    .lookup_offset(PlainDateTime::of(2011, 7, 15).to_unix_second())
    .seconds(),
    14400,
  )
}

///|
test "Windows fields describe biases and recurring dates" {
  let zone = Zone::from_windows_rules("Eastern Standard Time", Some(2007), [
    eastern_windows_record,
  ])
  guard zone.future is Some((_, Windows(rule))) else {
    fail("Expected Windows recurrence")
  }
  assert_eq(rule.standard.seconds(), -18000)
  assert_eq(rule.daylight.seconds(), -14400)
  assert_true(rule.daylight.is_dst())
  assert_false(zone.is_fixed())
  debug_inspect(
    rule.start,
    content="MonthWeekDay(month=3, week=2, weekday=0, second=7200)",
  )
  debug_inspect(
    rule.end,
    content="MonthWeekDay(month=11, week=1, weekday=0, second=7200)",
  )
}

///|
test "Windows snapshots use the same gap and overlap policies as TZif" {
  let zone = Zone::from_windows_rules("Eastern Standard Time", Some(2007), [
    eastern_windows_record,
  ])
  // March 10, 2024 skips 02:00–02:59. November 3 repeats 01:00–01:59.
  for
    (policy, gap_hour, gap_offset, repeated_offset) in [
      (Compatible, 3, -14400, -14400),
      (Earlier, 1, -18000, -14400),
      (Later, 3, -14400, -18000),
    ] {
    let gap = ZonedDateTime::of(
      2024,
      3,
      10,
      hour=2,
      minute=30,
      zone~,
      disambiguation=policy,
    )
    assert_eq(gap.hour(), gap_hour)
    assert_eq(gap.minute(), 30)
    assert_eq(gap.offset.seconds(), gap_offset)
    let overlap = ZonedDateTime::of(
      2024,
      11,
      3,
      hour=1,
      minute=30,
      zone~,
      disambiguation=policy,
    )
    assert_eq(overlap.hour(), 1)
    assert_eq(overlap.offset.seconds(), repeated_offset)
  }
  @test.assert_raise(() => {
    ZonedDateTime::of(
      2024,
      3,
      10,
      hour=2,
      minute=30,
      zone~,
      disambiguation=Reject,
    )
  })
  @test.assert_raise(() => {
    ZonedDateTime::of(
      2024,
      11,
      3,
      hour=1,
      minute=30,
      zone~,
      disambiguation=Reject,
    )
  })
}

///|
test "annual US changes become a finite table with recurring endpoints" {
  // Actual 2006 US rule: first Sunday in April through last Sunday in October.
  // The 2007 record changes only these month/week fields.
  let before : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    standard_date: {
      ..eastern_windows_record.standard_date,
      month: 10,
      day: 5,
    },
    daylight_date: { ..eastern_windows_record.daylight_date, month: 4, day: 1, },
  }
  let zone = Zone::from_windows_rules("Eastern Standard Time", Some(2006), [
    before, eastern_windows_record,
  ])
  assert_true(zone.past is Some((_, Windows(_))))
  assert_true(zone.future is Some((_, Windows(_))))
  assert_true(zone.transitions.length() <= 6)
  for
    (year, month, day, expected) in [
      (2005, 3, 20, -18000), // First endpoint repeats the old rule backward.
      (2006, 3, 20, -18000), // Recorded old rule: March is standard time.
      (2007, 3, 20, -14400), // Recorded new rule: March is daylight time.
      (2040, 3, 20, -14400), // Last endpoint repeats the new rule forward.
      (2040, 12, 20, -18000),
    ] {
    assert_eq(
      zone
      .lookup_offset(
        PlainDateTime::of(year, month, day, hour=12).to_unix_second(),
      )
      .seconds(),
      expected,
    )
  }
}

///|
test "base-offset changes at annual joins retain gap and overlap behavior" {
  // Synthetic edge: two fixed annual records, a half-hour change at New Year.
  for (before_bias, after_bias) in [(0, -30), (-30, 0)] {
    let rules : Array[WindowsTimeZoneInfo] = [before_bias, after_bias].map(bias => {
      bias,
      standard_bias: 2147483647, // Ignored when there are no seasonal dates.
      daylight_bias: -2147483648,
      standard_date: windows_no_date,
      daylight_date: windows_no_date,
    })
    let zone = Zone::from_windows_rules("Annual boundary", Some(2023), rules)
    let wall = PlainDateTime::of(2024, 1, 1).to_unix_second()
    let at = wall + before_bias.to_int64() * 60L
    assert_eq(zone.lookup_offset(at - 1).seconds(), -before_bias * 60)
    assert_eq(zone.lookup_offset(at).seconds(), -after_bias * 60)
    let plain = if after_bias < before_bias {
      PlainDateTime::of(2024, 1, 1, minute=15) // Forward jump skips 00:00–00:29.
    } else {
      PlainDateTime::of(2023, 12, 31, hour=23, minute=45) // Backward jump repeats 23:30–23:59.
    }
    let earlier = ZonedDateTime::from_plain(
      plain,
      zone~,
      disambiguation=Earlier,
    )
    let later = ZonedDateTime::from_plain(plain, zone~, disambiguation=Later)
    assert_eq(later.to_unix_second() - earlier.to_unix_second(), 1800L)
    @test.assert_raise(() => {
      ZonedDateTime::from_plain(plain, zone~, disambiguation=Reject)
    })
  }
}

///|
test "absolute transition dates are one-off events" {
  // Synthetic absolute dates with Eastern offsets, only in 2024. Weekday is
  // ignored for absolute SYSTEMTIME values; the actual month/day owns the date.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    standard_date: {
      ..eastern_windows_record.standard_date,
      year: 2024,
      day: 3,
      weekday: 65535,
    },
    daylight_date: {
      ..eastern_windows_record.daylight_date,
      year: 2024,
      day: 10,
      weekday: 65535,
    },
  }
  let zone = Zone::from_windows_rules("Absolute dates", None, [record])
  assert_true(zone.past is Some((_, Fixed(_))))
  assert_true(zone.future is Some((_, Fixed(_))))
  for
    (year, expected) in [
      (2023, -18000),
      (2024, -14400),
      (2025, -18000),
      (2424, -18000),
    ] {
    assert_eq(
      zone
      .lookup_offset(PlainDateTime::of(year, 7, 1).to_unix_second())
      .seconds(),
      expected,
    )
  }
  for instant in [@int64.MIN_VALUE, @int64.MAX_VALUE] {
    assert_eq(zone.lookup_offset(instant).seconds(), -18000)
  }
}

///|
test "absolute Windows daylight intervals can span calendar years" {
  // Synthetic one-time season with Eastern offsets: October 1, 2023 at
  // 02:00 standard time until April 7 at 02:00 daylight time in a later year.
  for end_year in [2024, 2026] {
    let record : WindowsTimeZoneInfo = {
      ..eastern_windows_record,
      daylight_date: {
        ..eastern_windows_record.daylight_date,
        year: 2023,
        month: 10,
        day: 1,
      },
      standard_date: {
        ..eastern_windows_record.standard_date,
        year: end_year,
        month: 4,
        day: 7,
      },
    }
    let enter = PlainDateTime::of(2023, 10, 1, hour=7).to_unix_second()
    let leave = PlainDateTime::of(end_year, 4, 7, hour=6).to_unix_second()
    for
      (first, rules) in [
        (None, [record]),
        (Some(2023), [record]),
        (Some(end_year), [record]),
        (Some(2023), [record, record]),
      ] {
      let zone = Zone::from_windows_rules("One-time winter DST", first, rules)
      for
        (instant, expected) in [
          (enter - 1, -18000), // Standard time before the one-time start.
          (enter, -14400), // The gap starts at exactly 07:00 UTC.
          (leave - 1, -14400), // DST remains active up to the end.
          (leave, -18000), // The overlap starts at exactly 06:00 UTC.
          (leave + 366L * 86400, -18000), // The season does not repeat.
        ] {
        assert_eq(zone.lookup_offset(instant).seconds(), expected)
      }
      for year in 2024..<=end_year {
        let new_year = PlainDateTime::of(year, 1, 1, hour=4).to_unix_second()
        for delta in [-1L, 0L, 1L] {
          assert_eq(zone.lookup_offset(new_year + delta).seconds(), -14400)
        }
      }
      let gap = ZonedDateTime::of(2023, 10, 1, hour=2, minute=30, zone~)
      assert_eq(gap.hour(), 3)
      let wall = PlainDateTime::of(end_year, 4, 7, hour=1, minute=30)
      let earlier = ZonedDateTime::from_plain(
        wall,
        zone~,
        disambiguation=Earlier,
      )
      let later = ZonedDateTime::from_plain(wall, zone~, disambiguation=Later)
      assert_eq(later.to_unix_second() - earlier.to_unix_second(), 3600L)
    }
  }
}

///|
test "absolute Windows end-of-day dates can cross the year boundary" {
  // Windows encodes next midnight as December 31 at 23:59:59.999.
  let midnight : WindowsSystemTime = {
    ..windows_no_date,
    year: 2023,
    month: 12,
    day: 31,
    hour: 23,
    minute: 59,
    second: 59,
    millisecond: 999,
  }
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    daylight_date: midnight,
    standard_date: { ..midnight, year: 2024, },
  }
  let zone = Zone::from_windows_rules("One-time year of DST", None, [record])
  let enter = PlainDateTime::of(2024, 1, 1, hour=5).to_unix_second()
  let leave = PlainDateTime::of(2025, 1, 1, hour=4).to_unix_second()
  for
    (instant, expected) in [
      (enter - 1, -18000),
      (enter, -14400),
      (leave - 1, -14400),
      (leave, -18000),
      (leave + 366L * 86400, -18000),
    ] {
    assert_eq(zone.lookup_offset(instant).seconds(), expected)
  }
}

///|
test "absolute Windows dates retain chronological order when standard comes first" {
  // The one-time end comes before the one-time start: daylight time before
  // April 2023 and after October 2024, standard time between the two events.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    standard_date: {
      ..eastern_windows_record.standard_date,
      year: 2023,
      month: 4,
      day: 7,
    },
    daylight_date: {
      ..eastern_windows_record.daylight_date,
      year: 2024,
      month: 10,
      day: 1,
    },
  }
  let zone = Zone::from_windows_rules("One-time standard interval", None, [
    record,
  ])
  let leave = PlainDateTime::of(2023, 4, 7, hour=6).to_unix_second()
  let enter = PlainDateTime::of(2024, 10, 1, hour=7).to_unix_second()
  for
    (instant, expected) in [
      (leave - 366L * 86400, -14400), // Before the first absolute event.
      (leave - 1, -14400),
      (leave, -18000),
      (PlainDateTime::of(2024, 1, 1).to_unix_second(), -18000),
      (enter - 1, -18000),
      (enter, -14400),
      (enter + 366L * 86400, -14400), // After the last absolute event.
    ] {
    assert_eq(zone.lookup_offset(instant).seconds(), expected)
  }
}

///|
test "Windows transition recurrence is independent for each date" {
  // Microsoft defines wYear separately on StandardDate and DaylightDate.
  // Each row gives the only interval whose offset differs from the baseline.
  let march = eastern_windows_record.daylight_date
  let november = eastern_windows_record.standard_date
  let april = { ..november, month: 4, }
  let october = { ..march, month: 10, day: 1, }
  for
    (start, end, first, last, baseline, inside) in [
      ( // One-time DST start; the yearly November end restores standard time.
        { ..march, year: 2024, day: 10, },
        november,
        PlainDateTime::of(2024, 3, 10, hour=7),
        PlainDateTime::of(2024, 11, 3, hour=6),
        -18000,
        -14400,
      ),
      ( // October's one-time start lasts until April of the following year.
        { ..october, year: 2024, day: 6, },
        april,
        PlainDateTime::of(2024, 10, 6, hour=7),
        PlainDateTime::of(2025, 4, 6, hour=6),
        -18000,
        -14400,
      ),
      ( // One-time standard start; the next yearly March start restores DST.
        march,
        { ..november, year: 2024, day: 3, },
        PlainDateTime::of(2024, 11, 3, hour=6),
        PlainDateTime::of(2025, 3, 9, hour=7),
        -14400,
        -18000,
      ),
      ( // April's one-time end lasts until the yearly October start.
        october,
        { ..april, year: 2024, day: 7, },
        PlainDateTime::of(2024, 4, 7, hour=6),
        PlainDateTime::of(2024, 10, 6, hour=7),
        -14400,
        -18000,
      ),
    ] {
    let record : WindowsTimeZoneInfo = {
      ..eastern_windows_record,
      daylight_date: start,
      standard_date: end,
    }
    for
      (first_year, rules) in [
        (None, [record]),
        (Some(2024), [record]),
        (Some(2024), [record, record]),
      ] {
      let zone = Zone::from_windows_rules(
        "Mixed Windows dates", first_year, rules,
      )
      let first = first.to_unix_second()
      let last = last.to_unix_second()
      for
        (instant, expected) in [
          (@int64.MIN_VALUE, baseline),
          (first - 1, baseline),
          (first, inside),
          (last - 1, inside),
          (last, baseline),
          (@int64.MAX_VALUE, baseline),
        ] {
        assert_eq(zone.lookup_offset(instant).seconds(), expected)
      }
      for year in 2022..<=2027 {
        for month in 1..<=12 {
          let instant = PlainDateTime::of(year, month, 15).to_unix_second()
          let expected = if first <= instant && instant < last {
            inside
          } else {
            baseline
          }
          assert_eq(zone.lookup_offset(instant).seconds(), expected)
        }
      }
    }
  }
}

///|
test "mixed Windows January dates are literal relative occurrences" {
  // The first Sunday of January 2025 is January 5, not January 1.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    daylight_date: {
      ..windows_no_date,
      year: 2024,
      month: 12,
      day: 15,
      hour: 2,
    },
    standard_date: { ..windows_no_date, month: 1, day: 1, },
  }
  let zone = Zone::from_windows_rules("January relative end", None, [record])
  let enter = PlainDateTime::of(2024, 12, 15, hour=7).to_unix_second()
  let leave = PlainDateTime::of(2025, 1, 5, hour=4).to_unix_second()
  for
    (time, expected) in [
      (enter - 1, -18000),
      (enter, -14400),
      (PlainDateTime::of(2025, 1, 1).to_unix_second(), -14400),
      (leave - 1, -14400),
      (leave, -18000),
      (PlainDateTime::of(2025, 12, 15).to_unix_second(), -18000),
    ] {
    assert_eq(zone.lookup_offset(time).seconds(), expected)
  }
}

///|
test "Windows mixed transitions work with positive negative and unchanged DST shifts" {
  for (bias, daylight_bias) in [(300, -60), (-60, 60), (-540, -30), (0, 0)] {
    let standard = -bias * 60
    let daylight = -(bias + daylight_bias) * 60
    for
      (start_once, end_once) in [
        (false, false),
        (false, true),
        (true, false),
        (true, true),
      ] {
      let record : WindowsTimeZoneInfo = {
        ..eastern_windows_record,
        bias,
        daylight_bias,
        daylight_date: if start_once {
          { ..eastern_windows_record.daylight_date, year: 2024, day: 10, }
        } else {
          eastern_windows_record.daylight_date
        },
        standard_date: if end_once {
          { ..eastern_windows_record.standard_date, year: 2024, day: 3, }
        } else {
          eastern_windows_record.standard_date
        },
      }
      let zone = Zone::from_windows_rules(
        "Independent recurrence matrix",
        None,
        [record],
      )
      // Expected active state comes from the documented occurrences, using
      // concrete calendar dates rather than the loader's date evaluator.
      let events = [
        (2023, 3, 12, true),
        (2023, 11, 5, false),
        (2024, 3, 10, true),
        (2024, 11, 3, false),
        (2025, 3, 9, true),
        (2025, 11, 2, false),
      ]
      let mut active = !start_once && end_once
      for (year, month, day, is_start) in events {
        let old = active
        let occurs = year == 2024 ||
          !(if is_start { start_once } else { end_once })
        if occurs {
          active = is_start
        }
        let wall = PlainDateTime::of(year, month, day, hour=2).to_unix_second()
        let instant = wall -
          (if is_start { standard } else { daylight }).to_int64()
        for
          (instant, expected) in [
            (instant - 1, old),
            (instant, active),
            (instant + 1, active),
          ] {
          let offset = zone.lookup_offset(instant)
          assert_eq(offset.is_dst(), expected)
          assert_eq(
            offset.seconds(),
            if expected {
              daylight
            } else {
              standard
            },
          )
        }
      }
    }
  }
}

///|
test "mixed Windows dates retain changes that skip or repeat New Year" {
  let june : WindowsSystemTime = {
    ..windows_no_date,
    month: 6,
    day: 1,
    hour: 2,
  }
  // Both changes occur at 23:30 UTC on December 31. The gap skips midnight;
  // the overlap repeats it. Splitting annual records must not move either.
  for
    (start, end, before, after) in [
      (
        {
          ..windows_no_date,
          year: 2023,
          month: 12,
          day: 31,
          hour: 23,
          minute: 30,
        },
        june,
        0,
        3600,
      ),
      (
        june,
        { ..windows_no_date, year: 2024, month: 1, day: 1, minute: 30, },
        3600,
        0,
      ),
    ] {
    let record : WindowsTimeZoneInfo = {
      bias: 0,
      standard_bias: 0,
      daylight_bias: -60,
      daylight_date: start,
      standard_date: end,
    }
    for (first, rules) in [(None, [record]), (Some(2023), [record, record])] {
      let zone = Zone::from_windows_rules("Mixed New Year", first, rules)
      let at = PlainDateTime::of(2023, 12, 31, hour=23, minute=30).to_unix_second()
      for
        (time, expected) in [
          (at - 3600, before),
          (at - 1, before),
          (at, after),
          (at + 1, after),
          (at + 3600, after),
        ] {
        assert_eq(zone.lookup_offset(time).seconds(), expected)
      }
      // 23:45 is skipped or repeated by the same half-hour-before-midnight change.
      let plain = PlainDateTime::of(2023, 12, 31, hour=23, minute=45)
      let earlier = ZonedDateTime::from_plain(
        plain,
        zone~,
        disambiguation=Earlier,
      )
      let later = ZonedDateTime::from_plain(plain, zone~, disambiguation=Later)
      assert_eq(later.to_unix_second() - earlier.to_unix_second(), 3600L)
      @test.assert_raise(() => {
        ZonedDateTime::from_plain(plain, zone~, disambiguation=Reject)
      })
    }
  }
}

///|
test "mixed Windows end-of-day and simultaneous transitions" {
  // December 31 was the last Sunday of December 2023. Its end-of-day
  // standard transition takes effect at 2024-01-01 04:00 UTC.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    daylight_date: {
      ..windows_no_date,
      year: 2023,
      month: 10,
      day: 1,
      hour: 2,
    },
    standard_date: {
      ..windows_no_date,
      month: 12,
      day: 5,
      hour: 23,
      minute: 59,
      second: 59,
      millisecond: 999,
    },
  }
  let zone = Zone::from_windows_rules("Mixed end of day", None, [record])
  let at = PlainDateTime::of(2024, 1, 1, hour=4).to_unix_second()
  assert_eq(zone.lookup_offset(at - 1).seconds(), -14400)
  assert_eq(zone.lookup_offset(at).seconds(), -18000)
  assert_eq(zone.lookup_offset(at + 366L * 86400).seconds(), -18000)

  // A one-time start at 01:00 standard and recurring end at 02:00 daylight
  // coincide at 06:00 UTC. Standard wins, so no daylight interval is created.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    daylight_date: {
      ..windows_no_date,
      year: 2024,
      month: 11,
      day: 3,
      hour: 1,
    },
  }
  let zone = Zone::from_windows_rules("Coincident mixed dates", None, [record])
  assert_true(zone.is_fixed())
  let at = PlainDateTime::of(2024, 11, 3, hour=6).to_unix_second()
  for time in [at - 1, at, at + 1] {
    assert_eq(zone.lookup_offset(time).seconds(), -18000)
    assert_false(zone.lookup_offset(time).is_dst())
  }
}

///|
test "equal absolute Windows dates ignore their weekday fields" {
  // Absolute November 3 is the same date regardless of the unused weekday.
  let date : WindowsSystemTime = {
    ..windows_no_date,
    year: 2024,
    month: 11,
    day: 3,
    hour: 2,
  }
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    standard_date: date,
    daylight_date: { ..date, weekday: 6, },
  }
  let zone = Zone::from_windows_rules("Equal absolute dates", None, [record])
  assert_true(zone.is_fixed())
  let at = PlainDateTime::of(2024, 11, 3, hour=6).to_unix_second()
  for time in [at - 1, at, at + 3600] {
    assert_eq(zone.lookup_offset(time).seconds(), -18000)
    assert_false(zone.lookup_offset(time).is_dst())
  }
}

///|
test "identical Windows transition dates disable daylight saving" {
  // Synthetic disabled-DST input: equal nonzero dates, with distinct biases.
  // Cover a recurring date, an absolute date, and the January boundary marker.
  for
    date in [
      eastern_windows_record.standard_date,
      { ..eastern_windows_record.standard_date, year: 2024, day: 3, },
      { ..windows_no_date, month: 1, day: 1, },
    ] {
    let record : WindowsTimeZoneInfo = {
      ..eastern_windows_record,
      standard_bias: 30,
      standard_date: date,
      daylight_date: date,
    }
    for
      (first, rules) in [
        (None, [record]),
        (Some(2024), [record]),
        (Some(2024), [record, record]),
      ] {
      let zone = Zone::from_windows_rules("Disabled DST", first, rules)
      assert_true(zone.is_fixed())
      // StandardBias still applies when nonzero transition dates coincide.
      // Equal dates must not expose the unused daylight offset as a candidate.
      assert_eq(zone.offset_candidates().length(), 1)
      for year in [2023, 2024, 2025] {
        for month in [1, 7, 12] {
          let instant = PlainDateTime::of(year, month, 15, hour=12).to_unix_second()
          let offset = zone.lookup_offset(instant)
          assert_eq(offset.seconds(), -19800)
          assert_false(offset.is_dst())
        }
      }
    }
  }
}

///|
test "distinct January markers still represent all-year daylight time" {
  // Synthetic edge: both dates normalize to YearBoundary, but their native
  // fields differ. They must not be mistaken for the disabled-DST sentinel.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    standard_date: { ..windows_no_date, month: 1, day: 1, weekday: 1, },
    daylight_date: { ..windows_no_date, month: 1, day: 1, weekday: 2, },
  }
  let zone = Zone::from_windows_rules("Year boundaries", None, [record])
  for month in [1, 7, 12] {
    let instant = PlainDateTime::of(2024, month, 15, hour=12).to_unix_second()
    let offset = zone.lookup_offset(instant)
    assert_eq(offset.seconds(), -14400)
    assert_true(offset.is_dst())
  }
}

///|
test "equal offset seconds retain distinct daylight metadata" {
  // Synthetic rule with no clock jump; the daylight designation is still data.
  let record : WindowsTimeZoneInfo = {
    ..eastern_windows_record,
    daylight_bias: 0,
  }
  let zone = Zone::from_windows_rules("Metadata", Some(2006), [record, record])
  assert_eq(zone.offsets.length(), 2)
  let winter = zone.lookup_offset(
    PlainDateTime::of(2007, 1, 15).to_unix_second(),
  )
  let summer = zone.lookup_offset(
    PlainDateTime::of(2007, 7, 15).to_unix_second(),
  )
  assert_eq(winter.seconds(), summer.seconds())
  assert_false(winter.is_dst())
  assert_true(summer.is_dst())
}

///|
test "Windows rules reject invalid year ranges and field values" {
  let record = eastern_windows_record
  for
    (first, rules) in [
      (None, []),
      (None, [record, record]),
      (Some(2007), []),
      (Some(0), [record]),
      (Some(-1), [record]),
      (Some(65536), [record]),
      (Some(65535), [record, record]),
    ] {
    @test.assert_raise(() => {
      Zone::from_windows_rules("Invalid range", first, rules)
    })
  }
  // Out-of-range bias, missing date, invalid weekday, and arbitrary subsecond
  // transitions are rejected independently of the native struct layout.
  let invalid : Array[WindowsTimeZoneInfo] = [
    { ..record, bias: 2147483647, },
    { ..record, standard_date: windows_no_date, },
    { ..record, standard_date: { ..record.standard_date, weekday: 7, }, },
    { ..record, standard_date: { ..record.standard_date, millisecond: 1, }, },
  ]
  for record in invalid {
    @test.assert_raise(() => {
      Zone::from_windows_rules("Invalid fields", Some(2007), [record])
    })
  }
}

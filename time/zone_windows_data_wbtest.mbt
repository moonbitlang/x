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
// Windows REG_TZI_FORMAT for the US Eastern rules in effect since 2007.
// UTC = local + bias. Standard bias is 300 minutes, daylight bias is 240.
// SYSTEMTIME fields: year, month, weekday, occurrence, hour, minute, second, ms.
let eastern_windows_record : Bytes = b"\x2c\x01\x00\x00" + // Bias: 300
  b"\x00\x00\x00\x00" + // StandardBias: 0
  b"\xc4\xff\xff\xff" + // DaylightBias: -60
  b"\x00\x00\x0b\x00\x00\x00\x01\x00\x02\x00\x00\x00\x00\x00\x00\x00" + // November, first Sunday, 02:00
  b"\x00\x00\x03\x00\x00\x00\x02\x00\x02\x00\x00\x00\x00\x00\x00\x00" // March, second Sunday, 02:00

///|
test "Windows Pyongyang snapshot agrees with TZif at its real offset changes" {
  let windows = Zone::from_windows_data(
    "North Korea Standard Time", windows_pyongyang,
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
  let zone = Zone::from_windows_data("Russian Standard Time", windows_moscow)
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
test "Windows snapshot decodes biases and recurring dates" {
  let data = b"\xd7\x07\x00\x00\xd7\x07\x00\x00" + eastern_windows_record
  let zone = Zone::from_windows_data("Eastern Standard Time", data)
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
  for length in 0..<data.length() {
    @test.assert_raise(() => Zone::from_windows_data("truncated", data[:length]))
  }
  @test.assert_raise(() => Zone::from_windows_data("trailing", data + b"x"))
  // Reversed/oversized year bounds, out-of-range bias, missing transition,
  // invalid weekday, and arbitrary subsecond transitions must fail on load.
  for
    (start, replacement) in [
      (0, b"\xd8\x07\x00\x00"),
      (4, b"\xff\xff\xff\xff"),
      (8, b"\xff\xff\xff\x7f"),
      (22, b"\x00\x00"),
      (24, b"\x07\x00"),
      (34, b"\x01\x00"),
    ] {
    let changed = Bytes::makei(data.length(), i => {
      if i >= start && i < start + replacement.length() {
        replacement[i - start]
      } else {
        data[i]
      }
    })
    @test.assert_raise(() => Zone::from_windows_data("invalid", changed))
  }
}

///|
test "Windows snapshots use the same gap and overlap policies as TZif" {
  let data = b"\xd7\x07\x00\x00\xd7\x07\x00\x00" + eastern_windows_record
  let zone = Zone::from_windows_data("Eastern Standard Time", data)
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
  let before = Bytes::makei(44, i => {
    match i {
      14 => 10 // StandardDate month: October
      18 => 5 // StandardDate occurrence: last Sunday
      30 => 4 // DaylightDate month: April
      34 => 1 // DaylightDate occurrence: first Sunday
      _ => eastern_windows_record[i]
    }
  })
  let data = b"\xd6\x07\x00\x00\xd7\x07\x00\x00" +
    before +
    eastern_windows_record
  let zone = Zone::from_windows_data("Eastern Standard Time", data)
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
    let data = @buffer.Buffer()
    data.write_int_le(2023)
    data.write_int_le(2024)
    for bias in [before_bias, after_bias] {
      data.write_int_le(bias)
      data.write_int_le(2147483647) // Ignored when there are no seasonal dates.
      data.write_int_le(-2147483648)
      data.write_bytes(Bytes::make(32, 0))
    }
    let zone = Zone::from_windows_data("Annual boundary", data.to_bytes())
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
  let data = @buffer.Buffer()
  data.write_int_le(0)
  data.write_int_le(0)
  data.write_int_le(300)
  data.write_int_le(0)
  data.write_int_le(-60)
  for (month, day) in [(11, 3), (3, 10)] {
    for field in [2024, month, 65535, day, 2, 0, 0, 0] {
      data.write_uint16_le(field.to_uint16())
    }
  }
  let bytes = data.to_bytes()
  let zone = Zone::from_windows_data("Absolute dates", bytes)
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
test "equal offset seconds retain distinct daylight metadata" {
  // Synthetic rule with no clock jump; the daylight designation is still data.
  let record = Bytes::makei(44, i => {
    if i >= 8 && i < 12 {
      b'\x00'
    } else {
      eastern_windows_record[i]
    }
  })
  let data = b"\xd6\x07\x00\x00\xd7\x07\x00\x00" + record + record
  let zone = Zone::from_windows_data("Metadata", data)
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

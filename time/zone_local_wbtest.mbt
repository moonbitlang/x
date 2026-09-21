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
// The same changes are supplied as explicit history and as a recurring rule.
// The unused offset must not affect the size of a gap or the chosen instant.
fn eastern_local_zone(recurring : Bool) -> Zone raise Error {
  {
    id: "Eastern",
    offsets: [
      ZoneOffset::from_seconds(-18000, abbrev="EST"),
      ZoneOffset::from_seconds(-14400, abbrev="EDT", dst=true),
      ZoneOffset::from_seconds(-16200, abbrev="Unused"),
    ],
    transitions: if recurring {
      []
    } else {
      [
        (PlainDateTime::of(2040, 3, 11, hour=7).to_unix_second(), 1),
        (PlainDateTime::of(2040, 11, 4, hour=6).to_unix_second(), 0),
      ]
    },
    future: if recurring {
      Some(ZoneFuture::from_posix(footer_fixture(eastern_footer)))
    } else {
      None
    },
  }
}

///|
test "local constructors preserve unambiguous clock readings" {
  for recurring in [false, true] {
    let zone = eastern_local_zone(recurring)
    for (month, day, hour, expected) in [(3, 11, 4, -14400), (11, 4, 2, -18000)] {
      let plain = PlainDateTime::of(
        2040,
        month,
        day,
        hour~,
        minute=30,
        nanosecond=123,
      )
      let value = ZonedDateTime::from_plain_datetime(plain, zone~)
      assert_eq(value.offset.seconds(), expected)
      let built = ZonedDateTime::of(
        2040,
        month,
        day,
        hour~,
        minute=30,
        nanosecond=123,
        zone~,
      )
      assert_eq(built.to_unix_second(), value.to_unix_second())
      let back = ZonedDateTime::from_unix_second(
        value.to_unix_second(),
        nanosecond=123,
        zone~,
      )
      assert_eq(back.datetime, plain)
      assert_eq(back.offset.seconds(), expected)
    }
  }
}

///|
test "local gaps shift forward and overlaps choose the earlier instant" {
  for recurring in [false, true] {
    let zone = eastern_local_zone(recurring)
    let gap = ZonedDateTime::of(
      2040,
      3,
      11,
      hour=2,
      minute=30,
      nanosecond=123,
      zone~,
    )
    assert_eq(
      gap.datetime,
      PlainDateTime::of(2040, 3, 11, hour=3, minute=30, nanosecond=123),
    )
    assert_eq(gap.offset.seconds(), -14400)
    let overlap = ZonedDateTime::of(2040, 11, 4, hour=1, minute=30, zone~)
    assert_eq(overlap.offset.seconds(), -14400)
    for value in [gap, overlap] {
      let back = ZonedDateTime::from_unix_second(
        value.to_unix_second(),
        nanosecond=value.nanosecond(),
        zone~,
      )
      assert_eq(back.datetime, value.datetime)
      assert_eq(back.offset.seconds(), value.offset.seconds())
    }
  }
}

///|
test "local edits retain an offset that remains valid in an overlap" {
  for recurring in [false, true] {
    let zone = eastern_local_zone(recurring)
    let second = PlainDateTime::of(2040, 11, 4, hour=6, minute=30).to_unix_second()
    let later = ZonedDateTime::from_unix_second(second, zone~)
    let edited = later.with_minute(45)
    assert_eq(edited.hour(), 1)
    assert_eq(edited.offset.seconds(), -18000)
    assert_eq(edited.to_unix_second(), second + 900)
    assert_eq(later.add_days(0).to_unix_second(), second)
  }
}

///|
test "local resolution handles half-hour and negative daylight changes" {
  for
    (footer, month, day, hour, minute, resolved_hour, resolved_minute, offset) in [
      (b"<+1030>-10:30<+11>-11,M10.1.0,M4.1.0", 10, 7, 2, 15, 2, 45, 39600),
      (b"<+1030>-10:30<+11>-11,M10.1.0,M4.1.0", 4, 1, 1, 45, 1, 45, 39600),
      (b"IST-1GMT0,M10.5.0,M3.5.0/1", 3, 25, 1, 30, 2, 30, 3600),
      (b"IST-1GMT0,M10.5.0,M3.5.0/1", 10, 28, 1, 30, 1, 30, 3600),
    ] {
    let zone = Zone::from_tzif_data("Seasonal", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(footer_fixture(footer)),
    })
    let value = ZonedDateTime::of(2040, month, day, hour~, minute~, zone~)
    assert_eq(value.hour(), resolved_hour)
    assert_eq(value.minute(), resolved_minute)
    assert_eq(value.offset.seconds(), offset)
    let back = ZonedDateTime::from_unix_second(value.to_unix_second(), zone~)
    assert_eq(back.datetime, value.datetime)
  }
}

///|
test "local resolution respects exact gap and overlap endpoints" {
  for recurring in [false, true] {
    let zone = eastern_local_zone(recurring)
    for
      (month, day, hour, minute, second, result_hour, offset) in [
        (3, 11, 1, 59, 59, 1, -18000),
        (3, 11, 2, 0, 0, 3, -14400),
        (3, 11, 2, 59, 59, 3, -14400),
        (3, 11, 3, 0, 0, 3, -14400),
        (11, 4, 0, 59, 59, 0, -14400),
        (11, 4, 1, 0, 0, 1, -14400),
        (11, 4, 1, 59, 59, 1, -14400),
        (11, 4, 2, 0, 0, 2, -18000),
      ] {
      let value = ZonedDateTime::of(
        2040,
        month,
        day,
        hour~,
        minute~,
        second~,
        zone~,
      )
      assert_eq(value.hour(), result_hour)
      assert_eq(value.minute(), minute)
      assert_eq(value.second(), second)
      assert_eq(value.offset.seconds(), offset)
    }
  }
}

///|
test "local gaps support skipped dates" {
  let zone : Zone = {
    id: "Skipped day",
    offsets: [ZoneOffset::from_seconds(-36000), ZoneOffset::from_seconds(50400)],
    transitions: [
      (PlainDateTime::of(2011, 12, 30, hour=10).to_unix_second(), 1),
    ],
    future: None,
  }
  let value = ZonedDateTime::of(2011, 12, 30, hour=12, zone~)
  assert_eq(value.datetime, PlainDateTime::of(2011, 12, 31, hour=12))
  assert_eq(value.offset.seconds(), 50400)
}

///|
test "known limitation: year 9999 gap retains the historical result" {
  // TODO: Decide the boundary policy before adding an error to local conversion.
  // Resolving this gap would produce 10000-01-01 00:30, outside our date range.
  // For now, preserve the old result; it does not round trip through Unix time.
  let zone : Zone = {
    id: "Out of range",
    offsets: [utc_offset, ZoneOffset::from_seconds(3600)],
    transitions: [
      (PlainDateTime::of(9999, 12, 31, hour=23).to_unix_second(), 1),
    ],
    future: None,
  }
  let plain = PlainDateTime::of(9999, 12, 31, hour=23, minute=30)
  for
    value in [
      ZonedDateTime::from_plain_datetime(plain, zone~),
      ZonedDateTime::of(9999, 12, 31, hour=23, minute=30, zone~),
    ] {
    assert_eq(value.datetime, plain)
    assert_eq(value.offset.seconds(), 3600)
    let back = ZonedDateTime::from_unix_second(value.to_unix_second(), zone~)
    assert_eq(
      back.datetime,
      PlainDateTime::of(9999, 12, 31, hour=22, minute=30),
    )
  }
}

///|
test "local resolution uses proleptic calendar rules and preserves type metadata" {
  let zone = eastern_local_zone(true)
  // -360 and 2040 are six whole Gregorian cycles apart.
  let value = ZonedDateTime::of(-360, 3, 11, hour=2, minute=30, zone~)
  assert_eq(value.datetime, PlainDateTime::of(-360, 3, 11, hour=3, minute=30))
  assert_eq(value.offset.seconds(), -14400)
  let zone = Zone::from_tzif_data("Same offset", {
    ..tzif_example,
    transitions: [],
    future_rule: Some(footer_fixture(b"STD0DST0,M3.2.0,M11.1.0")),
  })
  let summer = ZonedDateTime::of(2040, 7, 1, zone~)
  assert_eq(summer.offset.abbreviation(), "DST")
  assert_true(summer.offset.is_dst())
  let winter = summer.with_month(12)
  assert_eq(winter.offset.abbreviation(), "STD")
  assert_false(winter.offset.is_dst())
}

///|
test "local construction round trips throughout transition days" {
  for recurring in [false, true] {
    let zone = eastern_local_zone(recurring)
    for (month, day) in [(3, 11), (11, 4)] {
      for hour in 0..<24 {
        for minute in [0, 15, 30, 45] {
          let value = ZonedDateTime::of(2040, month, day, hour~, minute~, zone~)
          let back = ZonedDateTime::from_unix_second(
            value.to_unix_second(),
            zone~,
          )
          assert_eq(back.datetime, value.datetime)
          assert_eq(back.offset.seconds(), value.offset.seconds())
          assert_eq(
            value.hour(),
            if month == 3 && hour == 2 {
              3
            } else {
              hour
            },
          )
        }
      }
    }
  }
}

///|
test "closely spaced jumps still resolve a gap forward" {
  // Two forward gaps overlap on the wall clock, separated by a backward jump.
  // Projecting through the first jump alone would move 00:01:15 backward.
  let zone : Zone = {
    id: "Close transitions",
    offsets: [
      utc_offset,
      ZoneOffset::from_seconds(100),
      ZoneOffset::from_seconds(-100),
    ],
    transitions: [(0L, 1), (20L, 2), (150L, 0)],
    future: None,
  }
  let value = ZonedDateTime::of(1970, 1, 1, minute=1, second=15, zone~)
  assert_eq(value.datetime, PlainDateTime::of(1970, 1, 1, minute=2, second=55))
  assert_eq(value.to_unix_second(), 175L)
}

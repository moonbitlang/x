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
// A minimal TZif v3 envelope lets tests describe rules in their actual textual
// format while keeping parsed footer records read-only outside @tzif.
fn footer_fixture(footer : Bytes) -> @tzif.PosixTz raise Error {
  let file = @buffer.Buffer()
  for _ in 0..<2 {
    file.write_bytes(b"TZif3")
    file.write_bytes(Bytes::make(15, b'\x00')) // Reserved header bytes.
    file.write_int_be(0) // UT/local indicators.
    file.write_int_be(0) // Standard/wall indicators.
    file.write_int_be(0) // Leap records.
    file.write_int_be(0) // Transitions: only the footer supplies rules.
    file.write_int_be(1) // One required local time type.
    file.write_int_be(4) // Designation bytes including NUL.
    file.write_int_be(0) // UTC offset in seconds.
    file.write_byte(b'\x00') // Standard time.
    file.write_byte(b'\x00') // Designation index.
    file.write_bytes(b"UTC\x00")
  }
  file.write_byte(b'\n')
  file.write_bytes(footer)
  file.write_byte(b'\n')
  @tzif.parse(file.to_bytes()).future_rule.unwrap()
}

///|
// Dates below are UTC and depend only on these rules, not a host database.
let eastern_footer : Bytes = b"EST5EDT,M3.2.0,M11.1.0"

///|
test "changing annual rule order does not invent a January transition" {
  // IANA tzcode's tzparse emits the two transitions in chronological order
  // for each year. In 2039 the September end precedes the September start;
  // that start remains in effect until September 2040's end. Merely entering
  // a year with the opposite rule order does not change the active offset.
  let zone = Zone::from_tzif_data("Changing order", {
    ..tzif_example,
    transitions: [],
    future_rule: Some(footer_fixture(b"STD0DST,M9.2.3,M9.2.4")),
  })
  for (year, dst) in [(2039, false), (2040, true), (2041, false)] {
    assert_eq(
      zone
      .lookup_offset(PlainDateTime::of(year, 5, 1).to_unix_second())
      .is_dst(),
      dst,
    )
  }
  let end = PlainDateTime::of(2040, 9, 13, hour=1).to_unix_second()
  assert_true(zone.lookup_offset(end - 1).is_dst())
  assert_false(zone.lookup_offset(end).is_dst())
}

///|
test "footer seasons have exact UTC boundaries across centuries" {
  let zone = Zone::from_tzif_data("Eastern", {
    ..tzif_example,
    transitions: [],
    local_time_types: [tzif_example.local_time_types[0]],
    future_rule: Some(footer_fixture(eastern_footer)),
  })
  assert_false(zone.is_fixed())
  for (year, march, november) in [(2040, 11, 4), (2100, 14, 7), (2400, 12, 5)] {
    let start = PlainDateTime::of(year, 3, march, hour=7).to_unix_second()
    let end = PlainDateTime::of(year, 11, november, hour=6).to_unix_second()
    for
      (second, dst) in [
        (start - 1, false),
        (start, true),
        (end - 1, true),
        (end, false),
      ] {
      let offset = zone.lookup_offset(second)
      assert_eq(offset.seconds(), if dst { -14400 } else { -18000 })
      assert_eq(offset.abbreviation(), if dst { "EDT" } else { "EST" })
      assert_eq(offset.is_dst(), dst)
    }
  }
  // A rule-only file applies before the epoch too, without table history.
  assert_eq(
    zone.lookup_offset(PlainDateTime::of(1900, 7, 1).to_unix_second()).seconds(),
    -14400,
  )
  // Their Gregorian representatives are January 2143 and December 2196.
  for second in [-9223372036854775808L, 9223372036854775807L] {
    assert_eq(zone.lookup_offset(second).seconds(), -18000)
  }
}

///|
test "footer begins at the last projected transition, preserving earlier history" {
  let cutoff = PlainDateTime::of(2040, 1, 1).to_unix_second()
  let zone = Zone::from_tzif_data("Eastern", {
    ..tzif_example,
    transitions: [
      { time: 0L, type_index: 1, },
      { time: cutoff + 1, type_index: 0, },
    ],
    local_time_types: [
      {
        ..tzif_example.local_time_types[0],
        offset: -18000,
        designation: b"EST",
      },
      tzif_example.local_time_types[1],
    ],
    leap_records: [{ time: 78796800L, correction: 1, }],
    future_rule: Some(footer_fixture(eastern_footer)),
  })
  assert_eq(zone.lookup_offset(-1L).seconds(), -18000) // Type 0, before history.
  assert_eq(zone.lookup_offset(cutoff - 1).seconds(), 0) // Last earlier record.
  assert_eq(zone.lookup_offset(cutoff).seconds(), -18000) // Footer, inclusive.
  assert_eq(
    zone.lookup_offset(PlainDateTime::of(2040, 7, 1).to_unix_second()).seconds(),
    -14400,
  )
}

///|
test "southern seasons support half-hour DST and negative DST" {
  // Lord Howe: standard +10:30, daylight +11:00; season crosses January.
  // Dublin: standard IST +01, daylight GMT +00; the DST flag is set in winter.
  let cases = [
    (
      b"<+1030>-10:30<+11>-11,M10.1.0,M4.1.0",
      PlainDateTime::of(2040, 10, 6, hour=15, minute=30),
      PlainDateTime::of(2040, 3, 31, hour=15),
    ),
    (
      b"IST-1GMT0,M10.5.0,M3.5.0/1",
      PlainDateTime::of(2040, 10, 28, hour=1),
      PlainDateTime::of(2040, 3, 25, hour=1),
    ),
  ]
  for (footer, start, end) in cases {
    let rule = footer_fixture(footer)
    let zone = Zone::from_tzif_data("Southern", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(rule),
    })
    let start = start.to_unix_second()
    let end = end.to_unix_second()
    for
      (second, dst) in [
        (PlainDateTime::of(2040, 1, 1).to_unix_second(), true),
        (end - 1, true),
        (end, false),
        (start - 1, false),
        (start, true),
      ] {
      let offset = zone.lookup_offset(second)
      assert_eq(offset.is_dst(), dst)
      assert_eq(
        offset.seconds(),
        if dst {
          rule.daylight.unwrap().offset
        } else {
          rule.standard_offset
        },
      )
      assert_eq(
        offset.abbreviation(),
        if dst {
          rule.daylight.unwrap().designation
        } else {
          rule.standard_designation
        },
      )
    }
  }
}

///|
test "Julian rules skip leap day, ordinal rules count it" {
  for
    (footer, dates) in [
      (b"STD0DST,J60/0,J300/0", [(2040, 3, 1), (2041, 3, 1), (2100, 3, 1)]),
      (b"STD0DST,59/0,J300/0", [(2040, 2, 29), (2041, 3, 1), (2100, 3, 1)]),
    ] {
    let zone = Zone::from_tzif_data("Julian", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(footer_fixture(footer)),
    })
    for (year, month, day) in dates {
      let start = PlainDateTime::of(year, month, day).to_unix_second()
      assert_false(zone.lookup_offset(start - 1).is_dst())
      assert_true(zone.lookup_offset(start).is_dst())
    }
  }
}

///|
test "extended transition times cross UTC year boundaries" {
  let cases = [
    // J1/-1: the next year's start occurs on December 31 at 23:00 UTC.
    (
      b"STD0DST,J1/-1,J180/0",
      PlainDateTime::of(2040, 12, 31, hour=23),
      true,
      true,
    ),
    // J365/26: the previous year's end occurs January 1 at 01:00 UTC.
    (
      b"STD0DST,J180/0,J365/26",
      PlainDateTime::of(2041, 1, 1, hour=1),
      false,
      true,
    ),
    // Both December transitions land in January; the older season still
    // applies at January 1, before either of last year's transitions.
    (
      b"STD0DST,J365/72,J365/48",
      PlainDateTime::of(2041, 1, 1, hour=23),
      false,
      true,
    ),
    // Each date crosses a year boundary in the opposite direction. The first
    // end after the shifted start belongs to the nominal year two years later.
    (
      b"STD0DST,J365/166:59:59,J1/-166:59:59",
      PlainDateTime::of(2040, 12, 25, second=1),
      false,
      false,
    ),
  ]
  for (footer, boundary, enters, january_dst) in cases {
    let zone = Zone::from_tzif_data("Extended", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(footer_fixture(footer)),
    })
    let second = boundary.to_unix_second()
    assert_eq(zone.lookup_offset(second - 1).is_dst(), !enters)
    assert_eq(zone.lookup_offset(second).is_dst(), enters)
    assert_eq(
      zone
      .lookup_offset(PlainDateTime::of(2041, 1, 1).to_unix_second())
      .is_dst(),
      january_dst,
    )
  }
}

///|
test "RFC all-year daylight rules leave no standard-time instant" {
  // RFC 9636 section 3.3.1: XXX3EDT4,0/0,J365/23.
  // Appendix A also gives EST5EDT,0/0,J365/25 for positive all-year DST.
  for
    (footer, standard_offset) in [
      (b"XXX3EDT4,0/0,J365/23", -10800),
      (b"EST5EDT,0/0,J365/25", -18000),
    ] {
    let zone = Zone::from_tzif_data("Permanent", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(footer_fixture(footer)),
    })
    for year in [1900, 2000, 2040, 2041, 2100, 2400] {
      for month in 1..<=12 {
        let second = PlainDateTime::of(year, month, 1).to_unix_second() -
          standard_offset.to_int64()
        for delta in [-1L, 0L, 1L] {
          let offset = zone.lookup_offset(second + delta)
          assert_eq(offset.seconds(), -14400)
          assert_true(offset.is_dst())
        }
      }
    }
  }
}

///|
test "fixed footer overrides type zero and preserves its designation" {
  let data = {
    ..tzif_example,
    transitions: [],
    future_rule: Some(footer_fixture(b"GMT0")),
  }
  let zone = Zone::from_tzif_data("Fixed", data)
  assert_true(zone.is_fixed())
  for second in [-9223372036854775808L, 0L, 9223372036854775807L] {
    let offset = zone.lookup_offset(second)
    assert_eq(offset.seconds(), 0)
    assert_eq(offset.abbreviation(), "GMT")
    assert_false(offset.is_dst())
  }
  let zone = Zone::from_tzif_data("History", {
    ..data,
    transitions: [{ time: 0L, type_index: 1, }],
    local_time_types: [
      data.local_time_types[0],
      { ..data.local_time_types[1], designation: b"GMT", is_dst: false, },
    ],
  })
  assert_eq(zone.lookup_offset(-1L).seconds(), 3600)
  assert_eq(zone.lookup_offset(0L).abbreviation(), "GMT")
  assert_false(zone.is_fixed())
}

///|
test "daylight footers need explicit rules and representable offsets" {
  for
    footer in [
      b"EST5EDT", b"EST5EDT-18:00:01,M3.2.0,M11.1.0", b"EST18:00:01EDT4,M3.2.0,M11.1.0",
    ] {
    // Parsing succeeds; Zone rejects rules it cannot evaluate or represent.
    let rule = footer_fixture(footer)
    @test.assert_raise(() => {
      Zone::from_tzif_data("Invalid", {
        ..tzif_example,
        transitions: [],
        future_rule: Some(rule),
      })
    })
  }
}

///|
test "overlapping annual daylight intervals have no intervening standard time" {
  // STD0DST,J1/-1,J365/25: each season overlaps the next by one hour.
  // Extended times can overlap by several days as well.
  for
    footer in [
      b"STD0DST,J1/-1,J365/25", b"STD0DST,J1/-166:59:59,J365/166:59:59",
    ] {
    let zone = Zone::from_tzif_data("Overlapping", {
      ..tzif_example,
      transitions: [],
      future_rule: Some(footer_fixture(footer)),
    })
    for year in [2040, 2041, 2100] {
      for month in 1..<=12 {
        let second = PlainDateTime::of(year, month, 1).to_unix_second()
        let offset = zone.lookup_offset(second)
        assert_eq(offset.seconds(), 3600)
        assert_true(offset.is_dst())
      }
    }
  }
}

///|
test "ordinal overlap preserves the explicit season in every nominal year" {
  // STD0DST,0/0,365/24 overlaps the next season in common years, but leaves
  // one hour of standard time at the end of leap years. Evaluate each year's
  // interval, including common years whose daylight period exceeds a year.
  let zone = Zone::from_tzif_data("Ordinal overlap", {
    ..tzif_example,
    transitions: [],
    future_rule: Some(footer_fixture(b"STD0DST,0/0,365/24")),
  })
  for
    (date, dst) in [
      (PlainDateTime::of(2040, 12, 31, hour=23), false),
      (PlainDateTime::of(2041, 1, 1), true),
      (PlainDateTime::of(2041, 7, 1), true),
      (PlainDateTime::of(2041, 12, 31, hour=23), true),
    ] {
    assert_eq(zone.lookup_offset(date.to_unix_second()).is_dst(), dst)
  }
}

///|
test "TZif rejects footers inconsistent with the final time type" {
  for
    (offset, is_dst, designation, footer) in [
      (3600, false, b"UTC", b"UTC0"),
      (0, true, b"UTC", b"UTC0"),
      (0, false, b"GMT", b"UTC0"),
      // Normalizing an unsupported designation must not hide disagreement.
      (0, false, b"\xff", b"<+00>0"),
    ] {
    let data = {
      ..tzif_example,
      transitions: [{ time: 0L, type_index: 0, }],
      local_time_types: [
        { ..tzif_example.local_time_types[0], offset, is_dst, designation, },
      ],
      future_rule: Some(footer_fixture(footer)),
    }
    @test.assert_raise(() => Zone::from_tzif_data("Inconsistent", data))
  }
}

///|
test "footer agreement uses the final projected Unix timestamp" {
  let start = PlainDateTime::of(2040, 3, 11, hour=7).to_unix_second()
  let standard = {
    ..tzif_example.local_time_types[0],
    offset: -18000,
    designation: b"EST",
    // These describe the source transition's encoding, not the time type
    // computed by the footer, and do not participate in the agreement check.
    is_standard: true,
    is_ut: true,
  }
  let data = {
    ..tzif_example,
    transitions: [{ time: start, type_index: 0, }],
    local_time_types: [standard],
    leap_records: [{ time: 78796800L, correction: 1, }],
    future_rule: Some(footer_fixture(eastern_footer)),
  }
  // The leap correction puts the last transition one second before DST.
  let zone = Zone::from_tzif_data("Projected", data)
  assert_eq(zone.lookup_offset(start - 1).seconds(), -18000)
  assert_eq(zone.lookup_offset(start).seconds(), -14400)
  @test.assert_raise(() => {
    Zone::from_tzif_data("Wrong projected type", {
      ..data,
      local_time_types: [
        { ..standard, offset: -14400, is_dst: true, designation: b"EDT", },
      ],
    })
  })
}

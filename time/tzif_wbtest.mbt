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
// A standard offset and a zero-offset daylight type, with transitions on both
// sides of the signed 32-bit range. Tests replace fields to state each case.
let tzif_example : @tzif.Data = {
  version: V2,
  transitions: [
    { time: -2147483649L, type_index: 1, },
    { time: 2147483648L, type_index: 0, },
  ],
  local_time_types: [
    {
      offset: 3600,
      is_dst: false,
      designation: b"STD",
      is_standard: false,
      is_ut: false,
    },
    {
      offset: 0,
      is_dst: true,
      designation: b"DST",
      is_standard: false,
      is_ut: false,
    },
  ],
  leap_records: [],
  future_rule: None,
}

///|
test "TZif converts Honolulu's explicit records" {
  // RFC 9636 Appendix B.2 (Table 2), authoritative transition records.
  // https://www.rfc-editor.org/rfc/rfc9636.html#appendix-B.2
  // The exact bytes and footer decoding are tested in internal/tzif.
  let honolulu : @tzif.Data = {
    version: V2,
    transitions: [
      { time: -2334101314L, type_index: 1, },
      { time: -1157283000L, type_index: 2, },
      { time: -1155436200L, type_index: 1, },
      { time: -880198200L, type_index: 3, },
      { time: -769395600L, type_index: 4, },
      { time: -765376200L, type_index: 1, },
      { time: -712150200L, type_index: 5, },
    ],
    local_time_types: [
      {
        offset: -37886,
        is_dst: false,
        designation: b"LMT",
        is_standard: false,
        is_ut: false,
      },
      {
        offset: -37800,
        is_dst: false,
        designation: b"HST",
        is_standard: false,
        is_ut: false,
      },
      {
        offset: -34200,
        is_dst: true,
        designation: b"HDT",
        is_standard: false,
        is_ut: false,
      },
      {
        offset: -34200,
        is_dst: true,
        designation: b"HWT",
        is_standard: false,
        is_ut: false,
      },
      {
        offset: -34200,
        is_dst: true,
        designation: b"HPT",
        is_standard: true,
        is_ut: true,
      },
      {
        offset: -36000,
        is_dst: false,
        designation: b"HST",
        is_standard: false,
        is_ut: false,
      },
    ],
    leap_records: [],
    future_rule: None,
  }
  let zone = Zone::from_tzif_data("Pacific/Honolulu", honolulu)
  assert_eq(zone.to_string(), "Pacific/Honolulu")
  assert_eq(zone.transitions[0].0, -2334101314L)
  assert_eq(zone.transitions.length(), 7)
  assert_eq(zone.lookup_offset(-2334101315L).seconds(), -37886)
  assert_eq(zone.lookup_offset(-2334101314L).seconds(), -37800)
  assert_eq(zone.offsets[4].abbreviation(), "HPT")
  assert_true(zone.offsets[4].is_dst())
}

///|
test "TZif retains wide transitions and zero-offset metadata" {
  let zone = Zone::from_tzif_data("test", tzif_example)
  debug_inspect(zone.transitions, content="[(-2147483649, 1), (2147483648, 0)]")
  assert_eq(zone.lookup_offset(-2147483650L).seconds(), 3600)
  for second in [-2147483649L, 2147483647L] {
    let offset = zone.lookup_offset(second)
    assert_eq(offset.seconds(), 0)
    assert_eq(offset.abbreviation(), "DST")
    assert_true(offset.is_dst())
  }
  assert_eq(zone.lookup_offset(2147483648L).seconds(), 3600)
}

///|
test "TZif designations use ASCII or fall back to the numeric offset" {
  // RFC 9636 section 4: unsupported characters use a signed numeric offset.
  // Valid UTF-8 outside ASCII is also outside the designation character set.
  for
    (designation, offset, expected) in [
      (b"GMT", 0, "GMT"),
      (b"-00", 0, "-00"),
      (b"+0530", 19800, "+0530"),
      (b"\xffST", 0, "+00"),
      (b"\xc3\xa9ST", 19800, "+0530"),
      (b"A B", -36000, "-1000"),
      (b"A_B", 1, "+000001"),
      (b"A\nB", -37886, "-103126"),
      (b"\x7f", 64800, "+1800"),
    ] {
    let data = {
      ..tzif_example,
      local_time_types: [
        tzif_example.local_time_types[0],
        { ..tzif_example.local_time_types[1], designation, offset, },
      ],
    }
    let zone = Zone::from_tzif_data("designations", data)
    assert_eq(zone.offsets[1].abbreviation(), expected)
    assert_eq(zone.offsets[1].seconds(), offset)
    assert_true(zone.offsets[1].is_dst())
  }
}

///|
test "TZif preserves the full Int64 range without leap corrections" {
  let data = {
    ..tzif_example,
    transitions: [
      { time: @int64.MIN_VALUE, type_index: 1, },
      { time: @int64.MAX_VALUE, type_index: 0, },
    ],
  }
  let zone = Zone::from_tzif_data("extremes", data)
  assert_eq(zone.transitions[0].0, @int64.MIN_VALUE)
  assert_eq(zone.transitions[1].0, @int64.MAX_VALUE)
  assert_eq(zone.lookup_offset(@int64.MIN_VALUE).seconds(), 0)
  assert_eq(zone.lookup_offset(@int64.MAX_VALUE).seconds(), 3600)
}

///|
test "TZif projects leap-bearing transitions onto Unix seconds" {
  // Positive leap on 1972-06-30, hypothetical negative leap on 1972-12-31.
  // Transitions immediately before, at, and after each occurrence.
  let data = {
    ..tzif_example,
    transitions: [
      { time: 78796799L, type_index: 0, },
      { time: 78796800L, type_index: 1, },
      { time: 78796801L, type_index: 0, },
      { time: 94694399L, type_index: 1, },
      { time: 94694400L, type_index: 0, },
      { time: 94694401L, type_index: 1, },
    ],
    leap_records: [
      { time: 78796800L, correction: 1, },
      { time: 94694400L, correction: 0, },
    ],
  }
  let zone = Zone::from_tzif_data("leaps", data)
  debug_inspect(
    zone.transitions,
    content=(
      #|[
      #|  (78796799, 0),
      #|  (78796800, 1),
      #|  (78796800, 0),
      #|  (94694398, 1),
      #|  (94694400, 0),
      #|  (94694401, 1),
      #|]
    ),
  )
  // A change during the inserted second must not affect the preceding second.
  assert_eq(zone.lookup_offset(78796799L).seconds(), 3600)
  // Changes during the inserted second and immediately afterward coincide;
  // the later transition determines the offset at the first ordinary second.
  assert_eq(zone.lookup_offset(78796800L).seconds(), 3600)
  assert_eq(zone.lookup_offset(94694397L).seconds(), 3600)
  assert_eq(zone.lookup_offset(94694398L).seconds(), 0)
  assert_eq(zone.lookup_offset(94694400L).seconds(), 3600)
  assert_eq(zone.lookup_offset(94694401L).seconds(), 0)
}

///|
test "TZif rejects unrepresentable Unix transitions after a negative leap" {
  let data = {
    ..tzif_example,
    transitions: [{ time: @int64.MAX_VALUE - 1L, type_index: 0, }],
    leap_records: [{ time: 78796799L, correction: -1, }],
  }
  assert_eq(
    Zone::from_tzif_data("last representable", data).transitions[0].0,
    @int64.MAX_VALUE,
  )
  let overflow = {
    ..data,
    transitions: [{ time: @int64.MAX_VALUE, type_index: 0, }],
  }
  try Zone::from_tzif_data("overflow", overflow) catch {
    Failure::Failure(message) => assert_eq(message, "Int64 overflow")
    error => raise error
  } noraise {
    _ => fail("expected Unix-second overflow")
  }
}

///|
test "TZif loader propagates parse errors" {
  // The parser's own tests cover malformed records and every truncated RFC
  // fixture. This checks that errors also pass through the public loader.
  for input in [b"", b"TZif", b"TZif2"] {
    try Zone::from_tzif("truncated", input) catch {
      @tzif.ParseError(_, _) => ()
      error => raise error
    } noraise {
      _ => fail("expected a parse error")
    }
  }
}

///|
test "TZif retains the ZoneOffset range restriction" {
  let data = {
    ..tzif_example,
    local_time_types: [
      { ..tzif_example.local_time_types[0], offset: 64801, },
      tzif_example.local_time_types[1],
    ],
  }
  @test.assert_raise(() => Zone::from_tzif_data("offset", data))
}

///|
test "v4 truncated positive leap history projects the first occurrence" {
  let data = {
    ..tzif_example,
    version: V4,
    transitions: [
      { time: 1483228826L, type_index: 1, },
      { time: 1483228827L, type_index: 0, },
    ],
    leap_records: [{ time: 1483228826L, correction: 27, }],
  }
  let zone = Zone::from_tzif_data("truncated history", data)
  debug_inspect(zone.transitions, content="[(1483228800, 1), (1483228800, 0)]")
  let unknown = {
    ..data,
    transitions: [{ time: 1483228825L, type_index: 0, }],
  }
  try Zone::from_tzif_data("unknown correction", unknown) catch {
    Failure::Failure(message) =>
      assert_eq(message, "TZif transition precedes known leap-second history")
    error => raise error
  } noraise {
    _ => fail("expected unknown leap correction")
  }
}

///|
test "v4 first leap corrections handle signs and Int bounds" {
  // The first correction's sign determines the first leap's direction.
  // Zero is a negative leap, and correction arithmetic must widen before ±1.
  for correction in [0, -27, @int.MIN_VALUE, @int.MAX_VALUE] {
    let time = 94694400L
    let data = {
      ..tzif_example,
      version: V4,
      transitions: [
        { time, type_index: 1, },
        { time: time + 1L, type_index: 0, },
      ],
      leap_records: [{ time, correction, }],
    }
    let zone = Zone::from_tzif_data("first leap", data)
    let expected = time - correction.to_int64()
    assert_eq(
      zone.transitions[0].0,
      if correction > 0 {
        expected + 1L
      } else {
        expected
      },
    )
    assert_eq(zone.transitions[1].0, expected + 1L)
  }
}

///|
test "v4 expiration keeps the last known correction" {
  let data = {
    ..tzif_example,
    version: V4,
    transitions: [
      { time: 1735344026L, type_index: 1, },
      { time: 1735344027L, type_index: 0, },
      { time: 1735344028L, type_index: 1, },
    ],
    leap_records: [
      { time: 1483228826L, correction: 27, },
      { time: 1735344027L, correction: 27, },
    ],
  }
  let zone = Zone::from_tzif_data("expired history", data)
  debug_inspect(
    zone.transitions,
    content="[(1735343999, 1), (1735344000, 0), (1735344001, 1)]",
  )
  // With no transitions, no conversion needs the missing earlier history.
  let without_transitions = { ..data, transitions: [], }
  assert_eq(
    Zone::from_tzif_data("no transitions", without_transitions).transitions.length(),
    0,
  )
}

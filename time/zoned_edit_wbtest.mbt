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
test "valid offsets take precedence over disambiguation when editing an overlap" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // On October 27, 02:30 occurs first at +02:00 and then at +01:00.
  // Editing the minute to 45 can select either occurrence of 02:45.
  let first = Some("2024-10-27T02:45:00.000000123+02:00[CEST]")
  let second = Some("2024-10-27T02:45:00.000000123+01:00[CET]")
  // None means the edit must raise. The last two columns give the result
  // when starting from the first or second occurrence, respectively.
  let cases : Array[(OffsetPolicy, Disambiguation, String?, String?)] = [
    // Offset   Disambiguation   From first   From second
    // Prefer keeps the original offset because it is still valid.
    (Prefer, Compatible, first, second),
    (Prefer, Earlier, first, second),
    (Prefer, Later, first, second),
    (Prefer, Reject, first, second),
    // Ignore discards the original offset and lets disambiguation choose.
    (Ignore, Compatible, first, first),
    (Ignore, Earlier, first, first),
    (Ignore, Later, second, second),
    (Ignore, Reject, None, None),
    // Use interprets the edited clock reading with the original offset.
    (Use, Compatible, first, second),
    (Use, Earlier, first, second),
    (Use, Later, first, second),
    (Use, Reject, first, second),
    // Reject accepts either original offset because both are valid here.
    (Reject, Compatible, first, second),
    (Reject, Earlier, first, second),
    (Reject, Later, first, second),
    (Reject, Reject, first, second),
  ]
  for (offset, disambiguation, from_first, from_second) in cases {
    for (occurrence, expected) in [(Earlier, from_first), (Later, from_second)] {
      let start = ZonedDateTime::of(
        2024,
        10,
        27,
        hour=2,
        minute=30,
        nanosecond=123,
        zone~,
        disambiguation=occurrence,
      )
      match expected {
        None =>
          @test.assert_raise(() => {
            start.with_minute(45, offset~, disambiguation~)
          })
        Some(expected) => {
          let result = start.with_minute(45, offset~, disambiguation~)
          assert_eq(result.to_string(), expected)
          let back = ZonedDateTime::from_unix_second(
            result.to_unix_second(),
            nanosecond=123,
            zone~,
          )
          assert_eq(back.datetime, result.datetime)
          assert_eq(back.offset, result.offset)
        }
      }
    }
  }
}

///|
test "offset mismatch is independent of local time ambiguity" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // January 15 at noon is +01:00. Changing the month to July requests an
  // unambiguous noon at +02:00, where the original offset is no longer valid.
  let winter = ZonedDateTime::of(2024, 1, 15, hour=12, nanosecond=123, zone~)
  let noon = Some("2024-07-15T12:00:00.000000123+02:00[CEST]")
  let one_pm = Some("2024-07-15T13:00:00.000000123+02:00[CEST]")
  let cases : Array[(OffsetPolicy, Disambiguation, String?)] = [
    // Offset   Disambiguation   Expected result (None means raise)
    // Prefer falls back to the zone's July offset, preserving noon.
    (Prefer, Compatible, noon),
    (Prefer, Earlier, noon),
    (Prefer, Later, noon),
    (Prefer, Reject, noon),
    // Ignore also resolves the requested noon using July's offset.
    (Ignore, Compatible, noon),
    (Ignore, Earlier, noon),
    (Ignore, Later, noon),
    (Ignore, Reject, noon),
    // Use interprets noon at +01:00: 11:00 UTC, which is 13:00 in Paris.
    (Use, Compatible, one_pm),
    (Use, Earlier, one_pm),
    (Use, Later, one_pm),
    (Use, Reject, one_pm),
    // Reject refuses the invalid +01:00 offset even without an ambiguity.
    (Reject, Compatible, None),
    (Reject, Earlier, None),
    (Reject, Later, None),
    (Reject, Reject, None),
  ]
  for (offset, disambiguation, expected) in cases {
    match expected {
      None =>
        @test.assert_raise(() => winter.with_month(7, offset~, disambiguation~))
      Some(expected) => {
        let summer = winter.with_month(7, offset~, disambiguation~)
        assert_eq(summer.to_string(), expected)
        assert_true(summer.offset.is_dst())
      }
    }
  }
}

///|
test "editing into a gap distinguishes offset policies from disambiguation" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  // On March 31, the clock jumps from 02:00 to 03:00. Both edits below
  // request the nonexistent 02:30, starting at either 01:30 or 03:30.
  let before = Some("2024-03-31T01:30:00+01:00[CET]")
  let after = Some("2024-03-31T03:30:00+02:00[CEST]")
  let cases : Array[(OffsetPolicy, Disambiguation, String?, String?)] = [
    // Offset   Disambiguation   From 01:30   From 03:30 (None means raise)
    // Neither original offset is valid for 02:30, so Prefer falls back.
    (Prefer, Compatible, after, after),
    (Prefer, Earlier, before, before),
    (Prefer, Later, after, after),
    (Prefer, Reject, None, None),
    // Ignore lets disambiguation shift backward, forward, or reject.
    (Ignore, Compatible, after, after),
    (Ignore, Earlier, before, before),
    (Ignore, Later, after, after),
    (Ignore, Reject, None, None),
    // Use projects 02:30+01:00 to 03:30, but 02:30+02:00 to 01:30.
    (Use, Compatible, after, before),
    (Use, Earlier, after, before),
    (Use, Later, after, before),
    (Use, Reject, after, before),
    // Reject refuses either original offset: 02:30 has no valid offset.
    (Reject, Compatible, None, None),
    (Reject, Earlier, None, None),
    (Reject, Later, None, None),
    (Reject, Reject, None, None),
  ]
  for (offset, disambiguation, from_before, from_after) in cases {
    for (hour, expected) in [(1, from_before), (3, from_after)] {
      let start = ZonedDateTime::of(2024, 3, 31, hour~, minute=30, zone~)
      match expected {
        None =>
          @test.assert_raise(() => start.with_hour(2, offset~, disambiguation~))
        Some(expected) =>
          assert_eq(
            start.with_hour(2, offset~, disambiguation~).to_string(),
            expected,
          )
      }
    }
  }
}

///|
test "every field edit can reselect a repeated local time" {
  let zone = Zone::from_tzif("Europe/Paris", paris_tzif)
  let start = ZonedDateTime::of(
    2024,
    10,
    27,
    hour=2,
    minute=30,
    second=15,
    nanosecond=123,
    zone~,
    disambiguation=Later,
  )
  for
    result in [
      start.with_year(2024, offset=Ignore, disambiguation=Earlier),
      start.with_month(10, offset=Ignore, disambiguation=Earlier),
      start.with_day(27, offset=Ignore, disambiguation=Earlier),
      start.with_ordinal(start.ordinal(), offset=Ignore, disambiguation=Earlier),
      start.with_hour(2, offset=Ignore, disambiguation=Earlier),
      start.with_minute(30, offset=Ignore, disambiguation=Earlier),
      start.with_second(15, offset=Ignore, disambiguation=Earlier),
      start.with_nanosecond(123, offset=Ignore, disambiguation=Earlier),
    ] {
    assert_eq(result.datetime, start.datetime)
    assert_eq(result.to_unix_second(), start.to_unix_second() - 3600)
  }
  for
    result in [
      start.with_year(2024),
      start.with_month(10),
      start.with_day(27),
      start.with_ordinal(start.ordinal()),
      start.with_hour(2),
      start.with_minute(30),
      start.with_second(15),
      start.with_nanosecond(123),
    ] {
    assert_eq(result.to_unix_second(), start.to_unix_second())
  }
}

///|
test "minute edits can enter a half-hour gap" {
  let zone = Zone::from_tzif("Asia/Pyongyang", pyongyang_tzif)
  // May 4, 2018 jumped from 23:30 +08:30 to May 5 00:00 +09:00.
  // Changing 23:15 to 23:45 therefore requests a nonexistent wall time.
  let start = ZonedDateTime::of(2018, 5, 4, hour=23, minute=15, zone~)
  let gap = start.with_minute(45)
  debug_inspect(gap.to_string(), content="\"2018-05-05T00:15:00+09:00[KST]\"")
  let earlier = start.with_minute(45, disambiguation=Earlier)
  assert_eq(earlier.datetime, start.datetime)
  assert_eq(earlier.offset.seconds(), 30600)
  let forced = start.with_minute(45, offset=Use, disambiguation=Reject)
  assert_eq(forced.to_unix_second(), gap.to_unix_second())
  @test.assert_raise(() => start.with_minute(45, offset=Reject))
  @test.assert_raise(() => start.with_minute(45, disambiguation=Reject))
}

///|
test "second edits respect second-sized gaps and overlaps" {
  // Synthetic edge case: a 28-second gap and overlap only one minute apart.
  let zone : Zone = {
    id: "Seconds",
    offsets: [utc_offset, ZoneOffset::from_seconds(28)],
    transitions: [(0L, 1), (60L, 0)],
    future: None,
  }
  let start = ZonedDateTime::from_unix_second(5, zone~) // 00:00:33+00:00:28
  let gap = start.with_second(10)
  assert_eq(gap.to_unix_second(), 10L)
  assert_eq(gap.second(), 38)
  assert_eq(start.with_second(10, offset=Use).to_unix_second(), -18L)
  @test.assert_raise(() => start.with_second(10, offset=Reject))
  let later = ZonedDateTime::from_unix_second(70, zone~) // Second 00:01:10
  assert_eq(later.with_second(15).to_unix_second(), 75L)
  assert_eq(later.with_second(15, offset=Ignore).to_unix_second(), 47L)
  assert_eq(later.with_second(15, disambiguation=Reject).to_unix_second(), 75L)
  @test.assert_raise(() => {
    later.with_second(15, offset=Ignore, disambiguation=Reject)
  })
}

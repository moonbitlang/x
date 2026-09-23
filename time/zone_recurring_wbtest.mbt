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
test "recurring scopes leave the intervening history intact" {
  let paris = Zone::from_tzif("Europe/Paris", paris_tzif)
  let (_, rule) = paris.future.unwrap()
  let until = PlainDateTime::of(2025, 1, 1).to_unix_second()
  let from = PlainDateTime::of(2039, 1, 1).to_unix_second()
  // Synthetic scope test: Paris's real rule on both sides of a UTC interval.
  // The two cutoffs are independent of the one recorded transition.
  let zone : Zone = {
    id: "Scoped recurrence",
    offsets: [utc_offset],
    transitions: [(until, 0)],
    past: Some((until, rule)),
    future: Some((from, rule)),
  }
  for
    (instant, expected) in [
      (until - 1, 3600), // Past rule still owns the preceding second.
      (until, 0), // Past cutoff belongs to recorded history.
      (from - 1, 0), // History persists up to the future cutoff.
      (from, 3600), // Future rule owns its cutoff.
    ] {
    assert_eq(zone.lookup_offset(instant).seconds(), expected)
  }
  let cases = [
    // year/month/day, policy, resulting hour and UTC offset.
    (2024, 3, 31, Earlier, 1, 3600), // Past rule's spring gap, backward.
    (2024, 3, 31, Compatible, 3, 7200), // Past rule's spring gap, forward.
    (2024, 10, 27, Earlier, 2, 7200), // Past rule's first repeated hour.
    (2024, 10, 27, Later, 2, 3600), // Past rule's second repeated hour.
    (2040, 3, 25, Earlier, 1, 3600), // Future rule's spring gap, backward.
    (2040, 3, 25, Compatible, 3, 7200), // Future rule's spring gap, forward.
    (2040, 10, 28, Earlier, 2, 7200), // Future rule's first repeated hour.
    (2040, 10, 28, Later, 2, 3600), // Future rule's second repeated hour.
  ]
  for (year, month, day, disambiguation, hour, seconds) in cases {
    let result = ZonedDateTime::of(
      year,
      month,
      day,
      hour=2,
      minute=30,
      zone~,
      disambiguation~,
    )
    assert_eq(result.hour(), hour)
    assert_eq(result.minute(), 30)
    assert_eq(result.offset.seconds(), seconds)
    let back = ZonedDateTime::from_unix_second(result.to_unix_second(), zone~)
    assert_eq(back.datetime, result.datetime)
  }
  // A dormant recurring rule cannot create a gap inside the UTC interval.
  let ordinary = ZonedDateTime::of(
    2030,
    3,
    31,
    hour=2,
    minute=30,
    zone~,
    disambiguation=Reject,
  )
  assert_eq(ordinary.hour(), 2)
  assert_eq(ordinary.offset.seconds(), 0)
}

///|
test "local resolution sees gaps and overlaps at rule cutoffs" {
  let cutoff = PlainDateTime::of(2040, 1, 1).to_unix_second()
  let plus_one = ZoneOffset::from_seconds(3600)
  let cases : Array[(Zone, Bool)] = [
    (
      {
        id: "Past gap",
        offsets: [plus_one],
        transitions: [],
        past: Some((cutoff, Fixed(utc_offset))),
        future: None,
      },
      true,
    ),
    (
      {
        id: "Future gap",
        offsets: [utc_offset],
        transitions: [],
        past: None,
        future: Some((cutoff, Fixed(plus_one))),
      },
      true,
    ),
    (
      {
        id: "Past overlap",
        offsets: [utc_offset],
        transitions: [],
        past: Some((cutoff, Fixed(plus_one))),
        future: None,
      },
      false,
    ),
    (
      {
        id: "Future overlap",
        offsets: [plus_one],
        transitions: [],
        past: None,
        future: Some((cutoff, Fixed(utc_offset))),
      },
      false,
    ),
  ]
  let plain = PlainDateTime::of(2040, 1, 1, minute=30)
  for (zone, gap) in cases {
    assert_false(zone.is_fixed())
    let earlier = ZonedDateTime::from_plain(
      plain,
      zone~,
      disambiguation=Earlier,
    )
    let later = ZonedDateTime::from_plain(plain, zone~, disambiguation=Later)
    assert_eq(earlier.to_unix_second(), cutoff - 1800)
    assert_eq(later.to_unix_second(), cutoff + 1800)
    // Gap: 00:30 becomes previous-day 23:30 or 01:30.
    // Overlap: both instants keep the requested 00:30 reading.
    assert_eq(earlier.hour(), if gap { 23 } else { 0 })
    assert_eq(later.hour(), if gap { 1 } else { 0 })
    let compatible = ZonedDateTime::from_plain(plain, zone~)
    assert_eq(
      compatible.to_unix_second(),
      if gap {
        later.to_unix_second()
      } else {
        earlier.to_unix_second()
      },
    )
    @test.assert_raise(() => {
      ZonedDateTime::from_plain(plain, zone~, disambiguation=Reject)
    })
  }
}

///|
test "fixed recurrence preserves metadata and fixed-zone detection" {
  let offset = { ..utc_offset, abbrev: "GMT", }
  let zone : Zone = {
    id: "GMT",
    offsets: [utc_offset],
    transitions: [],
    past: None,
    future: Some((@int64.MIN_VALUE, Fixed(offset))),
  }
  assert_true(zone.is_fixed())
  assert_eq(zone.lookup_offset(@int64.MIN_VALUE).abbreviation(), "GMT")
  assert_eq(zone.lookup_offset(@int64.MAX_VALUE).abbreviation(), "GMT")
}

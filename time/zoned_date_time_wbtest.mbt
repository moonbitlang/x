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
/// A zone whose offset jumps from +01:00 (CET) to +02:00 (CEST) at the
/// given instant, mimicking a spring-forward transition.
fn spring_forward_zone(transition : Int64) -> Zone raise {
  {
    id: "Test/DST",
    offsets: [
      ZoneOffset::from_seconds(3600, abbrev="CET"),
      ZoneOffset::from_seconds(7200, abbrev="CEST", dst=true),
    ],
    transitions: [(transition, 1)],
  }
}

///|
/// A zone whose offset falls back from +02:00 (CEST) to +01:00 (CET) at the
/// given instant.
fn fall_back_zone(transition : Int64) -> Zone raise {
  {
    id: "Test/DST",
    offsets: [
      ZoneOffset::from_seconds(7200, abbrev="CEST", dst=true),
      ZoneOffset::from_seconds(3600, abbrev="CET"),
    ],
    transitions: [(transition, 1)],
  }
}

///|
test "from_plain_datetime before a DST transition" {
  let transition = PlainDateTime::of(2024, 3, 31, hour=1).to_unix_second()
  let zone = spring_forward_zone(transition)
  let zdt = ZonedDateTime::from_plain_datetime(
    PlainDateTime::of(2024, 1, 15, hour=12),
    zone~,
  )
  inspect(zdt.offset(), content="+01:00")
  inspect(
    zdt.to_unix_second(),
    content=PlainDateTime::of(2024, 1, 15, hour=11).to_unix_second().to_string(),
  )
  inspect(
    zone.lookup_offset(zdt.to_unix_second()) == zdt.offset(),
    content="true",
  )
}

///|
test "from_plain_datetime after a DST transition" {
  let transition = PlainDateTime::of(2024, 3, 31, hour=1).to_unix_second()
  let zone = spring_forward_zone(transition)
  let zdt = ZonedDateTime::from_plain_datetime(
    PlainDateTime::of(2024, 7, 1, hour=12),
    zone~,
  )
  inspect(zdt.offset(), content="+02:00")
  inspect(
    zdt.to_unix_second(),
    content=PlainDateTime::of(2024, 7, 1, hour=10).to_unix_second().to_string(),
  )
  inspect(
    zone.lookup_offset(zdt.to_unix_second()) == zdt.offset(),
    content="true",
  )
}

///|
test "from_plain_datetime just before a DST transition" {
  let transition = PlainDateTime::of(2024, 3, 31, hour=1).to_unix_second()
  let zone = spring_forward_zone(transition)
  // 01:30 local is still in standard time on the transition day, but it is
  // less than one offset change away from the transition instant, so using
  // the wall-clock value as the first instant guess suggests +02:00. The
  // offset has to be re-resolved to +01:00.
  let before = ZonedDateTime::from_plain_datetime(
    PlainDateTime::of(2024, 3, 31, hour=1, minute=30),
    zone~,
  )
  inspect(before.offset(), content="+01:00")
  inspect(
    before.to_unix_second(),
    content=PlainDateTime::of(2024, 3, 31, hour=0, minute=30)
      .to_unix_second()
      .to_string(),
  )
  inspect(
    zone.lookup_offset(before.to_unix_second()) == before.offset(),
    content="true",
  )
}

///|
test "from_plain_datetime inside a DST gap" {
  let transition = PlainDateTime::of(2024, 3, 31, hour=1).to_unix_second()
  let zone = spring_forward_zone(transition)
  // 02:30 local does not exist on the spring-forward day: it sits inside the
  // one-hour gap between +01:00 and +02:00. The first guess (+02:00) is
  // inconsistent with the instant it implies (00:30Z, which is before the
  // transition and therefore still +01:00), so the offset has to be
  // re-resolved. The old single-guess implementation kept +02:00 and
  // produced an instant one hour earlier.
  let gap = ZonedDateTime::from_plain_datetime(
    PlainDateTime::of(2024, 3, 31, hour=2, minute=30),
    zone~,
  )
  inspect(gap.offset(), content="+01:00")
  // The instant corresponds to 03:30 local time: the wall-clock time shifted
  // forward by the size of the gap, matching Temporal's `compatible`
  // disambiguation. Note that a gap value cannot be fully self-consistent:
  // the stored wall-clock fields are still the ones that were passed in, so
  // `offset` is not the zone's offset at `to_unix_second` (no offset exists
  // for a local time that is skipped). Resolving that would require also
  // rewriting the wall-clock fields, which `create_from_plain` does not do.
  inspect(
    gap.to_unix_second(),
    content=PlainDateTime::of(2024, 3, 31, hour=1, minute=30)
      .to_unix_second()
      .to_string(),
  )
}

///|
test "from_plain_datetime for an ambiguous local time" {
  // The fall-back transition at 2024-10-27T01:00:00Z: 02:30 local occurs
  // twice, at 00:30Z in summer time and at 01:30Z in standard time.
  let transition = PlainDateTime::of(2024, 10, 27, hour=1).to_unix_second()
  let zone = fall_back_zone(transition)
  let ambiguous = ZonedDateTime::from_plain_datetime(
    PlainDateTime::of(2024, 10, 27, hour=2, minute=30),
    zone~,
  )
  // The later (standard-time) occurrence is picked, not Temporal's
  // `compatible` default of the earlier one.
  inspect(ambiguous.offset(), content="+01:00")
  inspect(
    ambiguous.to_unix_second(),
    content=PlainDateTime::of(2024, 10, 27, hour=1, minute=30)
      .to_unix_second()
      .to_string(),
  )
}

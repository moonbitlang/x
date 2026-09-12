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
test "fixed" {
  inspect(Zone::fixed_zone("CST", 8 * 60 * 60), content="CST")
  inspect(Zone::fixed_zone("CST", 8 * 60 * 60).is_fixed(), content="true")
}

///|
test "utc" {
  inspect(@time.utc_zone, content="UTC")
}

///|
test "fixed_zone" {
  // A zero offset with the "UTC" id returns the canonical UTC zone.
  inspect(Zone::fixed_zone("UTC", 0) == @time.utc_zone, content="true")
  // A non-zero offset is kept, even when the id is "UTC".
  inspect(
    @time.ZonedDateTime::of(2000, 1, 1, zone=Zone::fixed_zone("UTC", 3600)),
    content="2000-01-01T00:00:00+01:00[UTC]",
  )
  // The abbreviation is used when formatting the zone.
  inspect(
    @time.ZonedDateTime::of(
      2000,
      1,
      1,
      zone=Zone::fixed_zone("CST", 8 * 60 * 60, abbrev="CST"),
    ),
    content="2000-01-01T00:00:00+08:00[CST]",
  )
  @test.assert_raise(() => Zone::fixed_zone("Bad", 19 * 60 * 60))
  @test.assert_raise(() => Zone::fixed_zone("Bad", -19 * 60 * 60))
}

///|
test "parse_str" {
  inspect(Zone::parse_str("UTC") == @time.utc_zone, content="true")
  inspect(Zone::parse_str("America/New_York"), content="America/New_York")
  inspect(Zone::parse_str("Asia/Shanghai"), content="Asia/Shanghai")
  inspect(Zone::parse_str("Etc/GMT+8"), content="Etc/GMT+8")
}

///|
test "parse_str errors" {
  let invalid : Array[String] = [
    "", "utc", "GMT", "A", "A/B/C", "A/", "/B", "Asia/Shanghai/",
  ]
  for s in invalid {
    @test.assert_raise(() => Zone::parse_str(s))
  }
}

///|
test "zone from_str" {
  inspect((@string.FromStr::from_str("UTC") : @time.Zone), content="UTC")
  inspect(
    (@string.FromStr::from_str("America/New_York") : @time.Zone),
    content="America/New_York",
  )
}

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
extern "js" fn runtime_zone_id() -> String =
  #| () => typeof globalThis.Temporal?.ZonedDateTime === "function"
  #|   ? Temporal.Now.timeZoneId() : new Intl.DateTimeFormat().resolvedOptions().timeZone

///|
test "JS local_zone captures the runtime timezone" {
  let zone = local_zone()
  assert_eq(zone.to_string(), runtime_zone_id())
  let date = ZonedDateTime::of(2024, 1, 15, hour=12, zone~)
  let back = ZonedDateTime::from_unix_second(date.to_unix_second(), zone~)
  assert_eq(back.datetime, date.datetime)
}

///|
test "JS Paris resolves clock readings across daylight-saving changes" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  // Winter and summer readings each identify one instant under every policy.
  for (month, expected_offset) in [(1, 3600), (7, 7200)] {
    for disambiguation in [Compatible, Earlier, Later, Reject] {
      let value = ZonedDateTime::of(
        2024,
        month,
        15,
        hour=12,
        zone~,
        disambiguation~,
      )
      assert_eq(value.hour(), 12)
      assert_eq(value.offset.seconds(), expected_offset)
    }
  }
  // Paris skips 02:00–02:59 in March and repeats it in October.
  let cases : Array[(String, Disambiguation, String)] = [
    // Requested wall time    Policy       Expected local result and offset
    (
      "2024-03-31T02:30:00",
      Compatible,
      "2024-03-31T03:30:00+02:00[Europe/Paris]",
    ),
    ("2024-03-31T02:30:00", Earlier, "2024-03-31T01:30:00+01:00[Europe/Paris]"),
    ("2024-03-31T02:30:00", Later, "2024-03-31T03:30:00+02:00[Europe/Paris]"),
    (
      "2024-10-27T02:30:00",
      Compatible,
      "2024-10-27T02:30:00+02:00[Europe/Paris]",
    ),
    ("2024-10-27T02:30:00", Earlier, "2024-10-27T02:30:00+02:00[Europe/Paris]"),
    ("2024-10-27T02:30:00", Later, "2024-10-27T02:30:00+01:00[Europe/Paris]"),
  ]
  for (wall, disambiguation, expected) in cases {
    let plain : PlainDateTime = @string.FromStr::from_str(wall)
    let value = ZonedDateTime::from_plain(plain, zone~, disambiguation~)
    assert_eq(value.to_string(), expected)
  }
  for (month, day) in [(3, 31), (10, 27)] {
    @test.assert_raise(() => {
      ZonedDateTime::of(
        2024,
        month,
        day,
        hour=2,
        minute=30,
        zone~,
        disambiguation=Reject,
      )
    })
  }
}

///|
test "JS Pyongyang preserves the real half-hour changes" {
  let js = get_js_timezone(id="Asia/Pyongyang")
  let zone = js.to_zone()
  // August 14, 2015 repeats 23:30–23:59; May 4, 2018 skips that interval.
  let cases : Array[(String, Disambiguation, String)] = [
    // Requested wall time    Policy       Expected local result and offset
    (
      "2015-08-14T23:45:00",
      Compatible,
      "2015-08-14T23:45:00+09:00[Asia/Pyongyang]",
    ),
    (
      "2015-08-14T23:45:00",
      Earlier,
      "2015-08-14T23:45:00+09:00[Asia/Pyongyang]",
    ),
    ("2015-08-14T23:45:00", Later, "2015-08-14T23:45:00+08:30[Asia/Pyongyang]"),
    (
      "2018-05-04T23:45:00",
      Compatible,
      "2018-05-05T00:15:00+09:00[Asia/Pyongyang]",
    ),
    (
      "2018-05-04T23:45:00",
      Earlier,
      "2018-05-04T23:15:00+08:30[Asia/Pyongyang]",
    ),
    ("2018-05-04T23:45:00", Later, "2018-05-05T00:15:00+09:00[Asia/Pyongyang]"),
  ]
  for (wall, disambiguation, expected) in cases {
    let plain : PlainDateTime = @string.FromStr::from_str(wall)
    let value = ZonedDateTime::from_plain(plain, zone~, disambiguation~)
    assert_eq(value.to_string(), expected)
  }
  for (year, month, day) in [(2015, 8, 14), (2018, 5, 4)] {
    @test.assert_raise(() => {
      ZonedDateTime::of(
        year,
        month,
        day,
        hour=23,
        minute=45,
        zone~,
        disambiguation=Reject,
      )
    })
  }
  let start = ZonedDateTime::of(2018, 5, 4, hour=23, minute=15, zone~)
  debug_inspect(
    start.with_minute(45).to_string(),
    content="\"2018-05-05T00:15:00+09:00[Asia/Pyongyang]\"",
  )
}

///|
test "JS offsets retain historical seconds, early years and nanoseconds" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  let early = ZonedDateTime::of(1900, 1, 1, zone~, nanosecond=999999999)
  assert_eq(early.offset.seconds(), 561) // Paris mean time: +00:09:21.
  debug_inspect(
    early.to_string(),
    content="\"1900-01-01T00:00:00.999999999+00:09:21[Europe/Paris]\"",
  )
  for year in [-9999, -1, 0, 1, 99, 1900, 1969, 9999] {
    let value = ZonedDateTime::of(year, 1, 1, zone~, nanosecond=999999999)
    assert_eq(value.offset.seconds(), if year <= 1900 { 561 } else { 3600 })
    let back = ZonedDateTime::from_unix_second(
      value.to_unix_second(),
      zone~,
      nanosecond=value.nanosecond(),
    )
    assert_eq(back.datetime, value.datetime)
    assert_eq(back.offset.seconds(), value.offset.seconds())
  }
  let negative = ZonedDateTime::from_unix_second(
    -1L,
    zone~,
    nanosecond=999999999,
  )
  assert_eq(
    ZonedDateTime::from_plain(negative.datetime, zone~).to_unix_second(),
    -1L,
  )
  assert_eq(negative.nanosecond(), 999999999)
}

///|
test "JS edits can keep or reselect a repeated clock reading" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  let first = Some("2024-10-27T02:45:00+02:00[Europe/Paris]")
  let second = Some("2024-10-27T02:45:00+01:00[Europe/Paris]")
  let cases : Array[(OffsetPolicy, Disambiguation, String?, String?)] = [
    // Offset   Disambiguation   From first occurrence   From second occurrence
    // None means the edit raises. Both original offsets are valid at 02:45.
    (Prefer, Compatible, first, second),
    (Prefer, Reject, first, second),
    (Ignore, Compatible, first, first),
    (Ignore, Earlier, first, first),
    (Ignore, Later, second, second),
    (Ignore, Reject, None, None),
    (Use, Reject, first, second),
    (Reject, Later, first, second),
  ]
  for (offset, disambiguation, from_first, from_second) in cases {
    for (occurrence, expected) in [(Earlier, from_first), (Later, from_second)] {
      let start = ZonedDateTime::of(
        2024,
        10,
        27,
        hour=2,
        minute=30,
        zone~,
        disambiguation=occurrence,
      )
      match expected {
        None =>
          @test.assert_raise(() => {
            start.with_minute(45, offset~, disambiguation~)
          })
        Some(expected) =>
          assert_eq(
            start.with_minute(45, offset~, disambiguation~).to_string(),
            expected,
          )
      }
    }
  }
}

///|
test "JS edits into a skipped hour resolve or reject explicitly" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  let before = Some("2024-03-31T01:30:00+01:00[Europe/Paris]")
  let after = Some("2024-03-31T03:30:00+02:00[Europe/Paris]")
  let cases : Array[(OffsetPolicy, Disambiguation, String?, String?)] = [
    // Edit the hour to 02:30, which does not exist. None means raise.
    // Offset   Disambiguation   From 01:30   From 03:30
    (Prefer, Compatible, after, after),
    (Prefer, Earlier, before, before),
    (Prefer, Reject, None, None),
    (Ignore, Earlier, before, before),
    (Ignore, Later, after, after),
    (Ignore, Reject, None, None),
    (Use, Reject, after, before), // Keep the old offset when computing the instant.
    (Reject, Compatible, None, None), // Neither old offset is valid at 02:30.
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
  let winter = ZonedDateTime::of(2024, 1, 15, hour=12, zone~)
  // Prefer keeps noon with July's +02 offset; Use keeps +01 when computing
  // the instant and yields 13:00. Reject refuses the original +01 offset.
  assert_eq(winter.with_month(7).hour(), 12)
  assert_eq(winter.with_month(7, offset=Use).hour(), 13)
  @test.assert_raise(() => winter.with_month(7, offset=Reject))
}

///|
test "JS calendar days and elapsed hours differ across DST" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  let start = ZonedDateTime::of(2024, 3, 30, hour=12, zone~)
  let day = start.add_days(1)
  let hours = start.add_hours(24)
  assert_eq(day.hour(), 12)
  assert_eq(day.to_unix_second() - start.to_unix_second(), 23L * 3600L)
  assert_eq(hours.hour(), 13)
  assert_eq(hours.to_unix_second() - start.to_unix_second(), 24L * 3600L)
}

///|
test "JS UTC and Etc zones resolve offsets and local readings" {
  // IANA's Etc/GMT names use the opposite sign to their UTC offset.
  for
    (id, expected_offset) in [
      ("UTC", 0),
      ("Etc/GMT-8", 28800),
      ("Etc/GMT+8", -28800),
    ] {
    let zone = get_js_timezone(id~).to_zone()
    for year in [-9999, 0, 1970, 2024, 9999] {
      let datetime = PlainDateTime::of(year, 7, 1, hour=12, nanosecond=123)
      for disambiguation in [Compatible, Earlier, Later, Reject] {
        let value = ZonedDateTime::from_plain(datetime, zone~, disambiguation~)
        assert_eq(value.datetime, datetime)
        assert_eq(value.offset.seconds(), expected_offset)
        assert_eq(
          value.to_unix_second(),
          datetime.to_unix_second() - expected_offset.to_int64(),
        )
        let back = ZonedDateTime::from_unix_second(
          value.to_unix_second(),
          nanosecond=123,
          zone~,
        )
        assert_eq(back.datetime, datetime)
        assert_eq(back.offset.seconds(), expected_offset)
      }
    }
  }
}

///|
test "JS timezone errors and unsupported instants" {
  @test.assert_raise(() => get_js_timezone(id="Not/AZone").to_zone())
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  assert_eq(zone, get_js_timezone(id="Europe/Paris").to_zone())
  for id in ["Europe/Paris", "UTC", "Etc/GMT-8"] {
    let zone = get_js_timezone(id~).to_zone()
    for
      second in [
        @int64.MIN_VALUE,
        @int64.MAX_VALUE,
        -8640000000001L,
        8640000000001L,
      ] {
      @test.assert_raise(() => ZonedDateTime::from_unix_second(second, zone~))
    }
  }
  let summer = ZonedDateTime::of(2024, 7, 1, zone~)
  assert_eq(summer.offset.seconds(), 7200)
  assert_eq(summer.offset.abbreviation(), "")
  assert_false(summer.offset.is_dst()) // Unavailable metadata, not standard time.
}

///|
extern "js" fn without_temporal(run : () -> String) -> String =
  #| run => {
  #|   const previous = globalThis.Temporal;
  #|   try { globalThis.Temporal = undefined; return run(); }
  #|   finally { globalThis.Temporal = previous; }
  #| }

///|
test "JS Date fallback loads a real zone when Temporal is absent" {
  let value = without_temporal(() => {
    try {
      let js = get_js_timezone(id="Europe/Paris")
      let zone = js.to_zone()
      ZonedDateTime::of(2024, 3, 31, hour=2, minute=30, zone~).to_string()
    } catch {
      error => error.to_string()
    }
  })
  assert_eq(value, "2024-03-31T03:30:00+02:00[Europe/Paris]")
}

///|
test "JS instant conversion changes offsets at the exact second" {
  let js = get_js_timezone(id="Europe/Paris")
  let zone = js.to_zone()
  // UTC clock reading          Paris wall time, with its offset.
  let cases = [
    ("2024-03-31T00:59:59", "2024-03-31T01:59:59.999999999+01:00[Europe/Paris]"),
    ("2024-03-31T01:00:00", "2024-03-31T03:00:00.999999999+02:00[Europe/Paris]"),
    ("2024-10-27T00:59:59", "2024-10-27T02:59:59.999999999+02:00[Europe/Paris]"),
    ("2024-10-27T01:00:00", "2024-10-27T02:00:00.999999999+01:00[Europe/Paris]"),
  ]
  for (utc, expected) in cases {
    let datetime : PlainDateTime = @string.FromStr::from_str(utc)
    let second = datetime.to_unix_second()
    let actual = ZonedDateTime::from_unix_second(
      second,
      nanosecond=999999999,
      zone~,
    )
    assert_eq(actual.to_string(), expected)
    assert_eq(actual.to_unix_second(), second)
  }
}

///|
test "JS timezone objects retain their own identifiers" {
  let paris = get_js_timezone(id="Europe/Paris").to_zone()
  let pyongyang = get_js_timezone(id="Asia/Pyongyang").to_zone()
  assert_eq(paris.to_string(), "Europe/Paris")
  assert_eq(pyongyang.to_string(), "Asia/Pyongyang")
  // The same instant is 14:00 in Paris and 21:00 in Pyongyang.
  let noon = PlainDateTime::of(2024, 7, 1, hour=12).to_unix_second()
  assert_eq(ZonedDateTime::from_unix_second(noon, zone=paris).hour(), 14)
  assert_eq(ZonedDateTime::from_unix_second(noon, zone=pyongyang).hour(), 21)
  assert_eq(ZonedDateTime::from_unix_second(noon, zone=paris).hour(), 14)
}

///|
test "JS Apia resolves the skipped calendar day" {
  let js = get_js_timezone(id="Pacific/Apia")
  let zone = js.to_zone()
  // Samoa moved from UTC-10 to UTC+14, skipping all of December 30, 2011.
  for
    (disambiguation, expected) in [
      (Earlier, "2011-12-29T12:00:00-10:00[Pacific/Apia]"),
      (Compatible, "2011-12-31T12:00:00+14:00[Pacific/Apia]"),
      (Later, "2011-12-31T12:00:00+14:00[Pacific/Apia]"),
    ] {
    let value = ZonedDateTime::of(2011, 12, 30, hour=12, zone~, disambiguation~)
    assert_eq(value.to_string(), expected)
  }
  @test.assert_raise(() => {
    ZonedDateTime::of(2011, 12, 30, hour=12, zone~, disambiguation=Reject)
  })
}

///|
test "JS New York resolves negative offsets and the repeated hour" {
  let js = get_js_timezone(id="America/New_York")
  let zone = js.to_zone()
  // Both occurrences show 01:30; the later occurrence is one hour later in UTC.
  for
    (disambiguation, expected) in [
      (Compatible, "2024-11-03T01:30:00-04:00[America/New_York]"),
      (Earlier, "2024-11-03T01:30:00-04:00[America/New_York]"),
      (Later, "2024-11-03T01:30:00-05:00[America/New_York]"),
    ] {
    let value = ZonedDateTime::of(
      2024,
      11,
      3,
      hour=1,
      minute=30,
      zone~,
      disambiguation~,
    )
    assert_eq(value.to_string(), expected)
  }
  let gap = ZonedDateTime::of(2024, 3, 10, hour=2, minute=30, zone~)
  debug_inspect(
    gap.to_string(),
    content="\"2024-03-10T03:30:00-04:00[America/New_York]\"",
  )
}

///|
extern "js" fn without_timezone_apis(run : () -> String) -> String =
  #| run => {
  #|   const temporal = globalThis.Temporal, intl = globalThis.Intl;
  #|   try {
  #|     globalThis.Temporal = undefined;
  #|     globalThis.Intl = undefined;
  #|     return run();
  #|   } finally {
  #|     globalThis.Temporal = temporal;
  #|     globalThis.Intl = intl;
  #|   }
  #| }

///|
test "JS unavailable timezone APIs raise a MoonBit error" {
  let message = without_timezone_apis(() => {
    try local_zone() catch {
      error => error.to_string()
    } noraise {
      _ => ""
    }
  })
  assert_true(
    message.contains(
      "local_zone requires Temporal or Date with Intl.DateTimeFormat",
    ),
  )
}

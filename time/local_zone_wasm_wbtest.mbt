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
test "linear Wasm loads a reusable system timezone" {
  let zone = local_zone()
  assert_false(zone.id.is_empty())
  for second in [-2208988800L, 1711846800L, 2208988800L] {
    assert_eq(
      ZonedDateTime::from_unix_second(second, zone~).to_unix_second(),
      second,
    )
  }
}

///|
test "Windows rule records retain signed biases and full transition fields" {
  // Win32 rule for US Eastern time: first Sunday of November at 02:00,
  // second Sunday of March at 02:00, with a -60 minute daylight bias.
  let rule = b"\x2c\x01\x00\x00\x00\x00\x00\x00\xc4\xff\xff\xff" +
    b"\x00\x00\x0b\x00\x00\x00\x01\x00\x02\x00\x00\x00\x00\x00\x00\x00" +
    b"\x00\x00\x03\x00\x00\x00\x02\x00\x02\x00\x00\x00\x00\x00\x00\x00"
  let capture : WindowsTimezone = { handle: 0UL, rule, }
  let zone = Zone::from_windows_rules("Eastern", None, [capture.read_rule()])
  let at = PlainDateTime::of(2025, 3, 9, hour=7).to_unix_second()
  assert_eq(zone.lookup_offset(at - 1).seconds(), -18000)
  assert_eq(zone.lookup_offset(at).seconds(), -14400)
}

///|
test "Windows wire dates preserve unsigned years and millisecond markers" {
  for
    (encoded, year, next_year) in [
      (b"\x00\x80", 32768, 971922585600L),
      (b"\xff\xff", 65535, 2005949145600L),
    ] {
    let date = decode_system_time(
      encoded + b"\x0c\x00\x06\x00\x1f\x00\x17\x00\x3b\x00\x3b\x00\xe7\x03",
    )
    assert_eq(date.year, year)
    assert_eq(date.month, 12)
    assert_eq(date.weekday, 6)
    assert_eq(date.day, 31)
    assert_eq(date.hour, 23)
    assert_eq(date.minute, 59)
    assert_eq(date.second, 59)
    assert_eq(date.millisecond, 999)
    guard date.to_transition() is Some(Once(second)) else {
      fail("Expected an absolute transition")
    }
    // The end-of-day marker carries into the following year without truncation.
    assert_eq(second, next_year)
  }
}

///|
test "metadata uses its byte length even when more UTF-16 follows" {
  let (name, disabled) = decode_metadata(
    b"\x01\x00\x00\x00\x02\x00\x00\x00A\x00B\x00",
  )
  assert_eq(name, "A")
  assert_true(disabled)
  // An odd count or a count extending beyond the buffer is malformed.
  for length in [b"\x01", b"\x04"] {
    @test.assert_raise(() => {
      ignore(
        decode_metadata(b"\x00\x00\x00\x00" + length + b"\x00\x00\x00A\x00"),
      )
    })
  }
}

///|
test "metadata preserves UTF-16 code units without interpreting a BOM or NUL" {
  let (name, _) = decode_metadata(
    b"\x00\x00\x00\x00\x0a\x00\x00\x00\xff\xfe\x3d\xd8\x00\xde\x00\x00\x00\xd8",
  )
  assert_eq(name.length(), 5)
  for i, unit in [0xfeff, 0xd83d, 0xde00, 0, 0xd800] {
    assert_eq(name[i].to_int(), unit)
  }
}

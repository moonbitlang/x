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
test "Duration roundtrip" {
  let actual = @time.Duration::of(hours=1L, minutes=2L)
  let json = ToJson::to_json(actual)
  let expected : Duration = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "PlainDate roundtrip" {
  let actual = @time.PlainDate::of(2000, 1, 2)
  let json = ToJson::to_json(actual)
  let expected : PlainDate = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "PlainTime roundtrip" {
  let actual = @time.PlainTime::of(3, 4, 5, 600)
  let json = ToJson::to_json(actual)
  let expected : PlainTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "PlainDateTime roundtrip" {
  let actual = @time.PlainDateTime::of(2000, 1, 2, hour=3, minute=4, second=5)
  let json = ToJson::to_json(actual)
  let expected : PlainDateTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "ZonedDateTime with id roundtrip" {
  let actual : ZonedDateTime = @json.from_json(
    "2026-09-12T14:30:00-05:00[America/New_York]",
  )

  let json = ToJson::to_json(actual)
  let expected : ZonedDateTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "ZonedDateTime roundtrip" {
  let actual : ZonedDateTime = @json.from_json("2026-09-12T14:30:00+05:30")

  let json = ToJson::to_json(actual)
  let expected : ZonedDateTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
fn expect_json_error(
  json : Json,
  expected_message : String,
  parse : (Json) -> Unit raise,
) -> Unit raise {
  try {
    parse(json)
    fail("expected JsonDecodeError")
  } catch {
    @json.JsonDecodeError((_, msg)) => inspect(msg, content=expected_message)
    _ => fail("unexpected error")
  }
}

///|
test "Period roundtrip" {
  let actual = @time.Period::of(years=1, months=2, days=3)
  let json = ToJson::to_json(actual)
  debug_inspect(json, content="String(\"P1Y2M3D\")")
  let expected : Period = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "ZoneOffset roundtrip" {
  let actual = @time.ZoneOffset::of(hours=-5, minutes=-30)
  let json = ToJson::to_json(actual)
  debug_inspect(json, content="String(\"-05:30\")")
  let expected : ZoneOffset = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "ZonedDateTime UTC roundtrip" {
  let actual = @time.ZonedDateTime::of(2000, 1, 1, hour=1, minute=2, second=3)
  let json = ToJson::to_json(actual)
  debug_inspect(json, content="String(\"2000-01-01T01:02:03Z\")")
  let expected : ZonedDateTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "ZonedDateTime nanosecond roundtrip" {
  let zone = Zone::fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  let actual = @time.unix(1714227729L, nanosecond=1000, zone~)
  let json = ToJson::to_json(actual)
  debug_inspect(
    json,
    content="String(\"2024-04-27T22:22:09.000001+08:00[Asia/Shanghai]\")",
  )
  let expected : ZonedDateTime = @json.from_json(json)
  assert_eq(actual, expected)
}

///|
test "json errors" {
  expect_json_error(Json::number(1), "Duration: expected string Number(1)", json => {
    let _ : Duration = @json.from_json(json)
  })
  expect_json_error(
    Json::string("nope"),
    "Duration: Invalid ISO8601 duration string nope",
    json => {
      let _ : Duration = @json.from_json(json)
    },
  )
  expect_json_error(Json::number(1), "Period: expected string Number(1)", json => {
    let _ : Period = @json.from_json(json)
  })
  expect_json_error(
    Json::string("nope"),
    "Period: Invalid ISO8601 string nope",
    json => {
      let _ : Period = @json.from_json(json)
    },
  )
  // An empty string must raise a decode error instead of panicking.
  expect_json_error(Json::string(""), "Period: Invalid ISO8601 string ", json => {
    let _ : Period = @json.from_json(json)
  })
  expect_json_error(Json::number(1), "ZoneOffset: expected string Number(1)", json => {
    let _ : ZoneOffset = @json.from_json(json)
  })
  expect_json_error(
    Json::string("nope"),
    "ZoneOffset: Invalid RFC3339 string nope",
    json => {
      let _ : ZoneOffset = @json.from_json(json)
    },
  )
  expect_json_error(
    Json::number(1),
    "ZonedDateTime: expected string Number(1)",
    json => {
      let _ : ZonedDateTime = @json.from_json(json)
    },
  )
  expect_json_error(
    Json::string("nope"),
    "ZonedDateTime: Invalid RFC3339 string nope",
    json => {
      let _ : ZonedDateTime = @json.from_json(json)
    },
  )
}

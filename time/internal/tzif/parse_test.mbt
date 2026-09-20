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
test "RFC 9636 v1 retains all leap records" {
  let data = @tzif.parse(rfc_b1)
  assert_eq(data.version, V1)
  assert_eq(data.transitions.length(), 0)
  assert_eq(data.leap_records.length(), 27)
  assert_eq(data.leap_records[0].time, 78796800L)
  assert_eq(data.leap_records[26].time, 1483228826L)
  assert_eq(data.leap_records[26].correction, 27)
  assert_eq(data.future_rule, None)
}

///|
test "RFC 9636 v2 selects the 64-bit block" {
  let data = @tzif.parse(rfc_b2)
  assert_eq(data.version, V2)
  assert_eq(data.transitions[0].time, -2334101314L)
  assert_eq(data.transitions.length(), 7)
  assert_eq(data.local_time_types[0].offset, -37886)
  assert_eq(data.local_time_types[4].designation, b"HPT")
  assert_true(data.local_time_types[4].is_standard)
  assert_true(data.local_time_types[4].is_ut)
  guard data.future_rule is Some(rule) else { fail("missing footer") }
  assert_eq(rule.standard_designation, "HST")
  assert_eq(rule.standard_offset, -36000)
  assert_eq(rule.daylight, None)
}

///|
test "RFC 9636 truncated v2 accepts a placeholder compatibility block" {
  let data = @tzif.parse(rfc_b3)
  assert_eq(data.version, V2)
  assert_eq(data.future_rule, None)
  assert_eq(
    data.local_time_types[data.transitions.last().unwrap().type_index].designation,
    b"-00",
  )
}

///|
test "RFC 9636 v3 footer and v4 truncated leap table" {
  let v3 = @tzif.parse(rfc_b4)
  assert_eq(v3.version, V3)
  assert_true(v3.future_rule is Some(_))
  let v4 = @tzif.parse(rfc_b5)
  assert_eq(v4.version, V4)
  assert_true(v4.leap_records[0].correction > 1)
  let records = v4.leap_records
  assert_eq(
    records[records.length() - 1].correction,
    records[records.length() - 2].correction,
  )
}

///|
test "every truncated RFC example returns a parse error" {
  for file in [rfc_b1, rfc_b2, rfc_b3, rfc_b4, rfc_b5] {
    for end in 0..<file.length() {
      @test.assert_raise(() => @tzif.parse(file[:end]))
    }
  }
}

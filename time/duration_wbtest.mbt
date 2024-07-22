// Copyright 2024 International Digital Economy Academy
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

test "of" {
  inspect!(
    Duration::of(hours=1L, minutes=2L, seconds=3L, nanoseconds=456789L)!!,
    content="Ok(PT1H2M3.000456789S)",
  )
  inspect!(
    Duration::of(seconds=-1L, nanoseconds=1000L)!!,
    content="Ok(PT-0.999999S)",
  )
  inspect!(
    Duration::of(seconds=-1L, nanoseconds=999_999_999L)!!,
    content="Ok(PT-0.000000001S)",
  )
  inspect!(
    Duration::of(hours=-1L, seconds=-10L, nanoseconds=2000000L)!!,
    content="Ok(PT-1H-9.998S)",
  )
  inspect!(
    Duration::of(nanoseconds=-20L * nanoseconds_per_second - 2L)!!,
    content="Ok(PT-20.000000002S)",
  )
  inspect!(Duration::of(nanoseconds=-200L)!!, content="Ok(PT-0.0000002S)")
}

test "add_hours" {
  inspect!(Duration::zero().add_hours(0L)!!, content="Ok(PT0S)")
  inspect!(Duration::zero().add_hours(1L)!!, content="Ok(PT1H)")
  inspect!(Duration::zero().add_hours(-1L)!!, content="Ok(PT-1H)")
  inspect!(
    Duration::zero().add_hours(Int64::max_value() / seconds_per_hour)!!,
    content="Ok(PT2562047788015215H)",
  )
  inspect!(
    Duration::zero().add_hours(Int64::min_value() / seconds_per_hour)!!,
    content="Ok(PT-2562047788015215H)",
  )
  inspect!(
    Duration::zero().add_hours(Int64::max_value())!!,
    content=
      #|Err("Int64 overflow")
  )
  inspect!(
    Duration::zero().add_hours(Int64::min_value())!!,
    content=
      #|Err("Int64 overflow")
  )
}

test "add_minutes" {
  inspect!(Duration::zero().add_minutes(0L)!!, content="Ok(PT0S)")
  inspect!(Duration::zero().add_minutes(1L)!!, content="Ok(PT1M)")
  inspect!(Duration::zero().add_minutes(-1L)!!, content="Ok(PT-1M)")
  inspect!(
    Duration::zero().add_minutes(Int64::max_value() / seconds_per_minute)!!,
    content="Ok(PT2562047788015215H30M)",
  )
  inspect!(
    Duration::zero().add_minutes(Int64::min_value() / seconds_per_minute)!!,
    content="Ok(PT-2562047788015215H-30M)",
  )
  inspect!(
    Duration::zero().add_minutes(Int64::max_value())!!,
    content=
      #|Err("Int64 overflow")
  )
  inspect!(
    Duration::zero().add_minutes(Int64::min_value())!!,
    content=
      #|Err("Int64 overflow")
  )
}

test "add_nanoseconds" {
  inspect!(Duration::zero().add_nanoseconds(0L)!!, content="Ok(PT0S)")
  inspect!(Duration::zero().add_nanoseconds(1L)!!, content="Ok(PT0.000000001S)")
  inspect!(
    Duration::zero().add_nanoseconds(-1L)!!,
    content="Ok(PT-0.000000001S)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(nanoseconds_per_second)!!,
    content="Ok(PT1S)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(-nanoseconds_per_second)!!,
    content="Ok(PT-1S)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(nanoseconds_per_minute)!!,
    content="Ok(PT1M)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(-nanoseconds_per_minute)!!,
    content="Ok(PT-1M)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(nanoseconds_per_hour)!!,
    content="Ok(PT1H)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(-nanoseconds_per_hour)!!,
    content="Ok(PT-1H)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(Int64::max_value())!!,
    content="Ok(PT2562047H47M16.854775807S)",
  )
  inspect!(
    Duration::zero().add_nanoseconds(Int64::min_value())!!,
    content="Ok(PT-2562047H-47M-16.854775808S)",
  )
  inspect!(
    Duration::of!(seconds=Int64::max_value()).add_nanoseconds(
      Int64::max_value(),
    )!!,
    content=
      #|Err("Int64 overflow")
  )
  inspect!(
    Duration::of!(seconds=Int64::min_value()).add_nanoseconds(
      Int64::min_value(),
    )!!,
    content=
      #|Err("Int64 overflow")
  )
}

test "op_add" {
  let p1 = Duration::of!(hours=1L, minutes=1L, seconds=1L, nanoseconds=1000L)
  let p2 = Duration::of!(
    hours=-1L,
    minutes=-1L,
    seconds=-1L,
    nanoseconds=-1000L,
  )
  let p3 = Duration::of!(
    seconds=Int64::max_value(),
    nanoseconds=max_nanosecond.to_int64(),
  )
  let p4 = Duration::of!(seconds=Int64::min_value())
  inspect!((p1 + Duration::zero())!!, content="Ok(PT1H1M1.000001S)")
  inspect!((p1 + p2)!!, content="Ok(PT0S)")
  inspect!((p1 + p1)!!, content="Ok(PT2H2M2.000002S)")
  inspect!((p2 + p2)!!, content="Ok(PT-2H-2M-2.000002S)")
  inspect!((p1 + p3)!!, content=
    #|Err("Int64 overflow")
  )
  inspect!((p2 + p4)!!, content=
    #|Err("Int64 overflow")
  )
}

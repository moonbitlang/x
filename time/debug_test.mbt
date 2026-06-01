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
test "debug" {
  debug_inspect(
    @time.Duration::of(hours=1L, minutes=2L),
    content="{ secs: 3720, nanos: 0 }",
  )
  debug_inspect(
    @time.Period::of(years=1, months=2, days=3),
    content="{ years: 1, months: 2, days: 3 }",
  )
  debug_inspect(
    @time.PlainDate::of(2000, 1, 2),
    content="{ year: 2000, month: 1, day: 2 }",
  )
  debug_inspect(
    @time.PlainTime::of(3, 4, 5, 600),
    content="{ hour: 3, minute: 4, second: 5, nanosecond: 600 }",
  )
  debug_inspect(
    @time.PlainDateTime::of(2000, 1, 2, hour=3, minute=4, second=5),
    content=(
      #|{
      #|  date: { year: 2000, month: 1, day: 2 },
      #|  time: { hour: 3, minute: 4, second: 5, nanosecond: 0 },
      #|}
    ),
  )
  let zone = @time.fixed_zone("Asia/Shanghai", 8 * 60 * 60)
  debug_inspect(
    zone,
    content=(
      #|{
      #|  id: "Asia/Shanghai",
      #|  offsets: [{ id: "+08:00", abbrev: "", seconds: 28800, dst: false }],
      #|  transitions: [],
      #|}
    ),
  )
  debug_inspect(
    @time.ZonedDateTime::of(2000, 1, 2, hour=3, minute=4, second=5, zone~),
    content=(
      #|{
      #|  datetime: {
      #|    date: { year: 2000, month: 1, day: 2 },
      #|    time: { hour: 3, minute: 4, second: 5, nanosecond: 0 },
      #|  },
      #|  zone: {
      #|    id: "Asia/Shanghai",
      #|    offsets: [{ id: "+08:00", abbrev: "", seconds: 28800, dst: false }],
      #|    transitions: [],
      #|  },
      #|  offset: { id: "+08:00", abbrev: "", seconds: 28800, dst: false },
      #|}
    ),
  )
}

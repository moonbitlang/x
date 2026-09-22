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
// Named Windows API fields; historical values and provenance are documented
// in testdata/windows/README.md. A zero month means no transition date.
let windows_no_date : WindowsSystemTime = {
  year: 0,
  month: 0,
  weekday: 0,
  day: 0,
  hour: 0,
  minute: 0,
  second: 0,
  millisecond: 0,
}

///|
// UTC = local + Bias + the applicable seasonal bias (all in minutes).
let eastern_windows_record : WindowsTimeZoneInfo = {
  bias: 300,
  standard_bias: 0,
  daylight_bias: -60,
  standard_date: { ..windows_no_date, month: 11, day: 1, hour: 2, }, // First Sunday in November.
  daylight_date: { ..windows_no_date, month: 3, day: 2, hour: 2, }, // Second Sunday in March.
}

///|
// Consecutive annual records, 2014–2019.
let pyongyang_windows_rules : Array[WindowsTimeZoneInfo] = [
  { // 2014
    bias: -540,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
  { // 2015
    bias: -510,
    standard_bias: 0,
    daylight_bias: -30,
    standard_date: {
      ..windows_no_date,
      month: 8,
      weekday: 5,
      day: 2,
      hour: 23,
      minute: 59,
      second: 59,
      millisecond: 999,
    },
    daylight_date: { ..windows_no_date, month: 1, weekday: 4, day: 1, },
  },
  { // 2016
    bias: -510,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
  { // 2017
    bias: -510,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
  { // 2018
    bias: -540,
    standard_bias: 0,
    daylight_bias: 30,
    standard_date: {
      ..windows_no_date,
      month: 5,
      weekday: 5,
      day: 1,
      hour: 23,
      minute: 30,
    },
    daylight_date: { ..windows_no_date, month: 1, weekday: 1, day: 1, },
  },
  { // 2019
    bias: -540,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
]

///|
// Consecutive annual records, 2010–2015.
let moscow_windows_rules : Array[WindowsTimeZoneInfo] = [
  { // 2010
    bias: -180,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: { ..windows_no_date, month: 10, day: 5, hour: 3, },
    daylight_date: { ..windows_no_date, month: 3, day: 5, hour: 2, },
  },
  { // 2011
    bias: -180,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: { ..windows_no_date, month: 1, weekday: 6, day: 1, },
    daylight_date: { ..windows_no_date, month: 3, day: 5, hour: 2, },
  },
  { // 2012
    bias: -240,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
  { // 2013
    bias: -240,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
  { // 2014
    bias: -180,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: { ..windows_no_date, month: 10, day: 5, hour: 2, },
    daylight_date: { ..windows_no_date, month: 1, weekday: 3, day: 1, },
  },
  { // 2015
    bias: -180,
    standard_bias: 0,
    daylight_bias: -60,
    standard_date: windows_no_date,
    daylight_date: windows_no_date,
  },
]

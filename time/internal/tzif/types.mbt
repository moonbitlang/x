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
pub(all) enum Version {
  V1
  V2
  V3
  V4
} derive(Eq, Debug)

///|
/// The authoritative data block. For versions 2–4, the 32-bit compatibility
/// block is skipped. An empty footer, or a version 1 file, has no future rule.
/// This is format data: parsing does not resolve local times or apply leaps.
pub(all) struct Data {
  version : Version
  transitions : Array[Transition]
  local_time_types : Array[LocalTimeType]
  leap_records : Array[LeapRecord]
  future_rule : PosixTz?
} derive(Eq, Debug)

///|
/// `time` is a TZif UNIX leap timestamp, not necessarily a POSIX timestamp.
/// `type_index` selects the local time type in effect from this transition.
pub(all) struct Transition {
  time : Int64
  type_index : Int
} derive(Eq, Debug)

///|
/// Offset seconds are added to universal time to obtain local time.
/// Designations are retained as bytes: older files need not contain UTF-8.
/// Missing standard/wall and UT/local indicators default to false.
pub(all) struct LocalTimeType {
  offset : Int
  is_dst : Bool
  designation : Bytes
  is_standard : Bool
  is_ut : Bool
} derive(Eq, Debug)

///|
/// A raw leap-table record, preserved without applying its correction.
/// In v4, a final record repeating the preceding correction is an expiration
/// marker. A first correction other than ±1 indicates missing earlier history.
pub(all) struct LeapRecord {
  time : Int64
  correction : Int
} derive(Eq, Debug)

///|
/// Parsed POSIX footer. Offsets use local-minus-UT seconds, consistently with
/// `LocalTimeType`, reversing the sign used in the footer's textual syntax.
pub struct PosixTz {
  standard_designation : String
  standard_offset : Int
  daylight : Daylight?
} derive(Eq, Debug)

///|
/// Missing rules remain unspecified; the parser never supplies host defaults.
pub struct Daylight {
  designation : String
  offset : Int
  rules : (Rule, Rule)?
} derive(Eq, Debug)

///|
/// A recurring transition's date and wall-clock seconds from that day's start.
/// Version 3 and 4 times can be negative or extend beyond the named day.
pub struct Rule {
  day : RuleDay
  time : Int
} derive(Eq, Debug)

///|
pub(all) enum RuleDay {
  JulianNoLeap(Int) // 1–365; February 29 is not counted.
  DayOfYear(Int) // 0–365; February 29 is counted.
  MonthWeekDay(month~ : Int, week~ : Int, weekday~ : Int) // Sunday = 0; week 5 = last.
} derive(Eq, Debug)

///|
/// The zero-based input byte offset and the reason parsing failed.
pub suberror ParseError {
  ParseError(Int, String)
} derive(Eq, Debug)

///|
#deprecated
pub extend Version with Eq::{not_equal, equal}

///|
#deprecated
pub extend Version with Debug::{to_repr}

///|
#deprecated
pub extend Data with Eq::{not_equal, equal}

///|
#deprecated
pub extend Data with Debug::{to_repr}

///|
#deprecated
pub extend Transition with Eq::{not_equal, equal}

///|
#deprecated
pub extend Transition with Debug::{to_repr}

///|
#deprecated
pub extend LocalTimeType with Eq::{not_equal, equal}

///|
#deprecated
pub extend LocalTimeType with Debug::{to_repr}

///|
#deprecated
pub extend LeapRecord with Eq::{not_equal, equal}

///|
#deprecated
pub extend LeapRecord with Debug::{to_repr}

///|
#deprecated
pub extend PosixTz with Eq::{not_equal, equal}

///|
#deprecated
pub extend PosixTz with Debug::{to_repr}

///|
#deprecated
pub extend Daylight with Eq::{not_equal, equal}

///|
#deprecated
pub extend Daylight with Debug::{to_repr}

///|
#deprecated
pub extend Rule with Eq::{not_equal, equal}

///|
#deprecated
pub extend Rule with Debug::{to_repr}

///|
#deprecated
pub extend RuleDay with Eq::{not_equal, equal}

///|
#deprecated
pub extend RuleDay with Debug::{to_repr}

///|
#deprecated
pub extend ParseError with Eq::{not_equal, equal}

///|
#deprecated
pub extend ParseError with Debug::{to_repr}

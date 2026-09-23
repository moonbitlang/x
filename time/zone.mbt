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
/// Time zone.
struct Zone {
  id : String
  offsets : Array[ZoneOffset]
  transitions : Array[(Int64, Int)] // (timestamp, offset_index)
  // Cutoffs mark the extent of recorded history; the end of a Windows annual
  // record's validity need not coincide with its last clock change.
  // Past excludes its cutoff; future includes it. Their scopes never overlap.
  past : (Int64, Recurring)?
  future : (Int64, Recurring)?
} derive(Eq, Debug)

///|
/// UTC time zone.
pub let utc_zone : Zone = {
  id: "UTC",
  offsets: [utc_offset],
  transitions: [],
  past: None,
  future: None,
}

///|
/// Creates a time zone with fixed offset from time zone id and offset seconds.
pub fn fixed_zone(
  id : String,
  offset_seconds : Int,
  abbrev? : String = "",
  dst? : Bool = false,
) -> Zone raise Error {
  let offset = ZoneOffset::from_seconds(offset_seconds, abbrev~, dst~)
  { id, offsets: [offset], transitions: [], past: None, future: None, }
}

///|
/// Checks if this zone has a single offset without seasonal rules.
pub fn Zone::is_fixed(self : Zone) -> Bool {
  self.offsets.length() == 1 &&
  [self.past, self.future]
  .iter()
  .all(tail => {
    match tail {
      None => true
      Some((_, Fixed(offset))) => self.offsets[0] == offset
      _ => false
    }
  })
}

///|
/// Returns the fixed zone id (e.g. "UTC", "America/Los_Angeles", etc.)
pub fn Zone::to_string(self : Zone) -> String {
  self.id
}

///|
pub impl Show for Zone with fn output(self : Zone, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn Zone::lookup_offset(self : Zone, secs : Int64) -> ZoneOffset {
  if self.past is Some((until, past)) && secs < until {
    return past.lookup_offset(secs)
  }
  if self.future is Some((from, future)) && secs >= from {
    return future.lookup_offset(secs)
  }
  if self.offsets.length() == 0 {
    return utc_offset
  }
  // Find the first transition strictly after secs. Leap projection can make
  // timestamps coincide, so the last record at or before secs must win.
  // Local resolution calls this for each candidate offset; keep it logarithmic
  // even for caller-supplied TZif files with large type and transition tables.
  let end = for low = 0, high = self.transitions.length(); low < high; {
    let mid = low + (high - low) / 2
    if self.transitions[mid].0 <= secs {
      continue mid + 1, high
    } else {
      continue low, mid
    }
  } nobreak {
    low
  }
  let offset_index = if end == 0 { 0 } else { self.transitions[end - 1].1 }
  self.offsets[offset_index]
}

///|
// Candidate metadata is refreshed by lookup_offset when resolving a local
// time. Deduplicate seconds without merging the stored historical types.
fn Zone::offset_candidates(self : Zone) -> Array[ZoneOffset] {
  let offsets = self.offsets.copy()
  for tail in [self.past, self.future] {
    if tail is Some((_, rule)) {
      for offset in rule.offsets() {
        offsets.push(offset)
      }
    }
  }
  let seen : Map[Int, Bool] = Map([])
  offsets.filter(offset => {
    if seen.contains(offset.seconds()) {
      false
    } else {
      seen[offset.seconds()] = true
      true
    }
  })
}

///|
// Include scope joins as well as recorded and recurring changes. A join can
// itself skip or repeat local readings, even if neither rule changes then.
fn Zone::transitions_near(
  self : Zone,
  year : Int,
  lower : Int64,
  upper : Int64,
) -> Array[Int64] {
  let changes = []
  for (time, _) in self.transitions {
    if time >= lower && time <= upper {
      changes.push(time)
    }
  }
  if self.past is Some((until, rule)) {
    if until >= lower && until <= upper {
      changes.push(until)
    }
    for time in rule.transitions_near(year) {
      if time >= lower && time <= upper && time < until {
        changes.push(time)
      }
    }
  }
  if self.future is Some((from, rule)) {
    if from >= lower && from <= upper {
      changes.push(from)
    }
    for time in rule.transitions_near(year) {
      if time >= lower && time <= upper && time >= from {
        changes.push(time)
      }
    }
  }
  changes.sort()
  changes
}

///|
/// Creates a time zone from a complete TZif v1–v4 file.
///
/// Versions 2–4 use the authoritative 64-bit transitions. Leap-bearing
/// timestamps are converted to Unix seconds; a transition during an inserted
/// leap second takes effect at the next ordinary second.
///
/// A transition preceding a truncated leap history raises an error because
/// its correction is unknown. After leap-table expiration, the last known
/// correction continues to apply, assuming no further leap corrections.
///
/// The footer governs timestamps on or after the last explicit transition,
/// or all timestamps when there are no transitions. Seasonal footer rules are
/// evaluated without consulting the host's timezone settings. A daylight
/// designation without transition rules raises an error, since its behavior
/// would require implementation-defined defaults.
/// A footer disagreeing with the final transition's offset, DST flag, or
/// designation also raises an error.
/// Before the first transition, type 0 is used. Without a footer, the last
/// explicit offset continues indefinitely (or type 0 when there are none).
/// Offsets must fit `ZoneOffset`'s range of -18 to +18 hours.
/// Designations containing characters other than ASCII letters, digits, `+`,
/// and `-` are replaced with the signed numeric offset, following RFC 9636.
pub fn Zone::from_tzif(id : String, data : BytesView) -> Zone raise Error {
  Zone::from_tzif_data(id, @tzif.parse(data))
}

///|
/// Compatibility entry point for callers with a `FixedArray[Byte]`.
/// Accepts the same TZif versions as `Zone::from_tzif`.
#deprecated("Use `Zone::from_tzif` with a `BytesView` instead")
pub fn Zone::from_tzif2(
  id : String,
  data : FixedArray[Byte],
) -> Zone raise Error {
  Zone::from_tzif(id, Bytes::from_array(data[:]))
}

///|
// Convert decoded records independently of the binary representation. The
// public loader supplies validated parser output; tests can supply records.
fn Zone::from_tzif_data(id : String, parsed : @tzif.Data) -> Zone raise Error {
  let offsets = parsed.local_time_types.map(time_type => {
    let offset = ZoneOffset::from_seconds(time_type.offset)
    // RFC 9636 section 4 recommends a numeric offset for unsupported bytes.
    // Validated ASCII bytes map directly to Unicode code points.
    let abbrev = if time_type.designation
      .iter()
      .all(byte => {
        byte is (b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'+' | b'-')
      }) {
      let name = StringBuilder()
      for byte in time_type.designation {
        name.write_char(byte.to_int().unsafe_to_char())
      }
      name.to_string()
    } else if time_type.offset == 0 {
      "+00"
    } else {
      offset.id().replace_all(old=":", new="")
    }
    // The public constructor canonicalizes zero to UTC; TZif metadata must
    // survive even when the offset is zero (e.g. GMT or Irish winter time).
    { ..offset, abbrev, dst: time_type.is_dst, }
  })
  let transitions = Array(capacity=parsed.transitions.length())
  let mut leap_index = 0
  let truncated_start = match parsed.leap_records {
    [first, ..] if first.correction != 1 && first.correction != -1 =>
      Some(first)
    _ => None
  }
  let mut correction = match truncated_start {
    Some(first) =>
      // Only the first retained leap's sign is known before processing it.
      // This prior value projects a transition during that inserted second;
      // it must never be used for transitions before the retained history.
      first.correction.to_int64() -
      (if first.correction > 0 { 1L } else { -1L })
    None => 0L
  }
  for transition in parsed.transitions {
    if truncated_start is Some(first) && transition.time < first.time {
      raise Failure::Failure(
        "TZif transition precedes known leap-second history",
      )
    }
    // Both tables are sorted. An expiration marker repeats the correction,
    // so this scan carries it forward as permitted by RFC 9636 section 4.
    while leap_index < parsed.leap_records.length() {
      let leap = parsed.leap_records[leap_index]
      if leap.time > transition.time {
        break
      }
      if leap.time == transition.time && leap.correction.to_int64() > correction {
        // An inserted second has no Unix-second representation. Use the old
        // correction here to place its transition at the following second,
        // rather than changing the offset one ordinary second too early.
        break
      }
      correction = leap.correction.to_int64()
      leap_index += 1
    }
    let time = checked_add_int64(transition.time, -correction)
    // Projection can coincide with the following transition. Keep file order
    // so lookup_offset selects the last change at that Unix second.
    transitions.push((time, transition.type_index))
  }
  let future = parsed.future_rule.map(Recurring::from_posix)
  if future is Some(future) && transitions.last() is Some((time, type_index)) {
    // RFC 9636 section 3.3 requires agreement at the last transition. Compare
    // at its projected Unix time, with the original designation: replacing
    // unsupported bytes with a numeric name must not conceal malformed input.
    let expected = parsed.local_time_types[type_index]
    let name = StringBuilder()
    for byte in expected.designation {
      name.write_char(byte.to_int().unsafe_to_char())
    }
    let actual = future.lookup_offset(time)
    // ZoneOffset equality compares only seconds, so check all three fields.
    guard actual.seconds() == expected.offset &&
      actual.is_dst() == expected.is_dst &&
      actual.abbreviation() == name.to_string() else {
      raise Failure::Failure("TZif footer disagrees with the final transition")
    }
  }
  // With no history, a fixed footer describes the entire zone. Preserve the
  // ordinary fixed-zone representation, including equality with utc_zone.
  if transitions.is_empty() && future is Some(Fixed(offset)) {
    return { id, offsets: [offset], transitions, past: None, future: None, }
  }
  let future = future.map(rule => {
    // A rule-only file covers the entire Unix-second domain.
    let from = match transitions.last() {
      Some((time, _)) => time
      None => @int64.MIN_VALUE
    }
    (from, rule)
  })
  { id, offsets, transitions, past: None, future, }
}

///|
test "Zone::from_tzif loads Los Angeles" {
  let data : Bytes = [
    // magic number
    84, 90, 105, 102,
    // version
     50,
    // unused
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    // ttisutcnt = 6
     0, 0, 0, 6,
    // ttisstdcnt = 6
     0, 0, 0, 6,
    // leapcnt = 0
     0, 0, 0, 0,
    // timecnt = 186
     0, 0, 0, 186,
    // typecnt = 6
     0, 0, 0, 6,
    // charcnt = 20
     0, 0, 0, 20,
    // data[44..]- transition timestamps
     128, 0, 0, 0, 158, 166, 72, 160, 159, 187, 21, 144, 160, 134, 42, 160, 161,
    154, 247, 144, 203, 137, 26, 160, 210, 35, 244, 112, 210, 97, 38, 16, 214, 254,
    116, 92, 216, 128, 173, 144, 218, 254, 195, 144, 219, 192, 144, 16, 220, 222,
    165, 144, 221, 169, 172, 144, 222, 190, 135, 144, 223, 137, 142, 144, 224, 158,
    105, 144, 225, 105, 112, 144, 226, 126, 75, 144, 227, 73, 82, 144, 228, 94, 45,
    144, 229, 41, 52, 144, 230, 71, 74, 16, 231, 18, 81, 16, 232, 39, 44, 16, 232,
    242, 51, 16, 234, 7, 14, 16, 234, 210, 21, 16, 235, 230, 240, 16, 236, 177, 247,
    16, 237, 198, 210, 16, 238, 145, 217, 16, 239, 175, 238, 144, 240, 113, 187,
    16, 241, 143, 208, 144, 242, 127, 193, 144, 243, 111, 178, 144, 244, 95, 163,
    144, 245, 79, 148, 144, 246, 63, 133, 144, 247, 47, 118, 144, 248, 40, 162, 16,
    249, 15, 88, 144, 250, 8, 132, 16, 250, 248, 131, 32, 251, 232, 102, 16, 252,
    216, 101, 32, 253, 200, 72, 16, 254, 184, 71, 32, 255, 168, 42, 16, 0, 152, 41,
    32, 1, 136, 12, 16, 2, 120, 11, 32, 3, 113, 40, 144, 4, 97, 39, 160, 5, 81, 10,
    144, 6, 65, 9, 160, 7, 48, 236, 144, 7, 141, 67, 160, 9, 16, 206, 144, 9, 173,
    191, 32, 10, 240, 176, 144, 11, 224, 175, 160, 12, 217, 205, 16, 13, 192, 145,
    160, 14, 185, 175, 16, 15, 169, 174, 32, 16, 153, 145, 16, 17, 137, 144, 32,
    18, 121, 115, 16, 19, 105, 114, 32, 20, 89, 85, 16, 21, 73, 84, 32, 22, 57, 55,
    16, 23, 41, 54, 32, 24, 34, 83, 144, 25, 9, 24, 32, 26, 2, 53, 144, 26, 242,
    52, 160, 27, 226, 23, 144, 28, 210, 22, 160, 29, 193, 249, 144, 30, 177, 248,
    160, 31, 161, 219, 144, 32, 118, 43, 32, 33, 129, 189, 144, 34, 86, 13, 32, 35,
    106, 218, 16, 36, 53, 239, 32, 37, 74, 188, 16, 38, 21, 209, 32, 39, 42, 158,
    16, 39, 254, 237, 160, 41, 10, 128, 16, 41, 222, 207, 160, 42, 234, 98, 16, 43,
    190, 177, 160, 44, 211, 126, 144, 45, 158, 147, 160, 46, 179, 96, 144, 47, 126,
    117, 160, 48, 147, 66, 144, 49, 103, 146, 32, 50, 115, 36, 144, 51, 71, 116,
    32, 52, 83, 6, 144, 53, 39, 86, 32, 54, 50, 232, 144, 55, 7, 56, 32, 56, 28,
    5, 16, 56, 231, 26, 32, 57, 251, 231, 16, 58, 198, 252, 32, 59, 219, 201, 16,
    60, 176, 24, 160, 61, 187, 171, 16, 62, 143, 250, 160, 63, 155, 141, 16, 64,
    111, 220, 160, 65, 132, 169, 144, 66, 79, 190, 160, 67, 100, 139, 144, 68, 47,
    160, 160, 69, 68, 109, 144, 69, 243, 211, 32, 71, 45, 138, 16, 71, 211, 181,
    32, 73, 13, 108, 16, 73, 179, 151, 32, 74, 237, 78, 16, 75, 156, 179, 160, 76,
    214, 106, 144, 77, 124, 149, 160, 78, 182, 76, 144, 79, 92, 119, 160, 80, 150,
    46, 144, 81, 60, 89, 160, 82, 118, 16, 144, 83, 28, 59, 160, 84, 85, 242, 144,
    84, 252, 29, 160, 86, 53, 212, 144, 86, 229, 58, 32, 88, 30, 241, 16, 88, 197,
    28, 32, 89, 254, 211, 16, 90, 164, 254, 32, 91, 222, 181, 16, 92, 132, 224, 32,
    93, 190, 151, 16, 94, 100, 194, 32, 95, 158, 121, 16, 96, 77, 222, 160, 97, 135,
    149, 144, 98, 45, 192, 160, 99, 103, 119, 144, 100, 13, 162, 160, 101, 71, 89,
    144, 101, 237, 132, 160, 103, 39, 59, 144, 103, 205, 102, 160, 105, 7, 29, 144,
    105, 173, 72, 160, 106, 230, 255, 144, 107, 150, 101, 32, 108, 208, 28, 16, 109,
    118, 71, 32, 110, 175, 254, 16, 111, 86, 41, 32, 112, 143, 224, 16, 113, 54,
    11, 32, 114, 111, 194, 16, 115, 21, 237, 32, 116, 79, 164, 16, 116, 255, 9, 160,
    118, 56, 192, 144, 118, 222, 235, 160, 120, 24, 162, 144, 120, 190, 205, 160,
    121, 248, 132, 144, 122, 158, 175, 160, 123, 216, 102, 144, 124, 126, 145, 160,
    125, 184, 72, 144, 126, 94, 115, 160, 127, 152, 42, 144,
    // offset indices per transition timestamp
     5, 1, 2, 1, 2, 3, 4, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2,
    1, 2, 1, 2,
    // data[974..]: offset 0: 4 for offset, 1 for isdst, 1 for abbreviation
     255, 255, 145, 38, 0, 0,
    // data[980..]: offset 1:
     255, 255, 157, 144, 1, 4,
    // data[986..]: offset 2:
     255, 255, 143, 128, 0, 8,
    // data[992..]: offset 3:
     255, 255, 157, 144, 1, 12,
    // data[998..]: offset 4:
     255, 255, 157, 144, 1, 16,
    // data[1004..]: offset 5:
     255, 255, 143, 128, 0, 8,
    // data[1008..]: abbrev 0: "LMT\0"
     76, 77, 84, 0,
    // data[1012..]: abbrev 1: "PDT\0"
     80, 68, 84, 0,
    // data[1016..]: abbrev 2: "PST\0"
     80, 83, 84, 0,
    // data[1020..]: abbrev 3: "PWT\0"
     80, 87, 84, 0,
    // data[1024..]: abbrev 4: "PPT\0"
     80, 80, 84, 0,
    // data[1028..]
     0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 84, 90, 105, 102, 50, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 186,
    0, 0, 0, 6, 0, 0, 0, 20, 255, 255, 255, 255, 94, 4, 26, 192, 255, 255, 255, 255,
    158, 166, 72, 160, 255, 255, 255, 255, 159, 187, 21, 144, 255, 255, 255, 255,
    160, 134, 42, 160, 255, 255, 255, 255, 161, 154, 247, 144, 255, 255, 255, 255,
    203, 137, 26, 160, 255, 255, 255, 255, 210, 35, 244, 112, 255, 255, 255, 255,
    210, 97, 38, 16, 255, 255, 255, 255, 214, 254, 116, 92, 255, 255, 255, 255, 216,
    128, 173, 144, 255, 255, 255, 255, 218, 254, 195, 144, 255, 255, 255, 255, 219,
    192, 144, 16, 255, 255, 255, 255, 220, 222, 165, 144, 255, 255, 255, 255, 221,
    169, 172, 144, 255, 255, 255, 255, 222, 190, 135, 144, 255, 255, 255, 255, 223,
    137, 142, 144, 255, 255, 255, 255, 224, 158, 105, 144, 255, 255, 255, 255, 225,
    105, 112, 144, 255, 255, 255, 255, 226, 126, 75, 144, 255, 255, 255, 255, 227,
    73, 82, 144, 255, 255, 255, 255, 228, 94, 45, 144, 255, 255, 255, 255, 229, 41,
    52, 144, 255, 255, 255, 255, 230, 71, 74, 16, 255, 255, 255, 255, 231, 18, 81,
    16, 255, 255, 255, 255, 232, 39, 44, 16, 255, 255, 255, 255, 232, 242, 51, 16,
    255, 255, 255, 255, 234, 7, 14, 16, 255, 255, 255, 255, 234, 210, 21, 16, 255,
    255, 255, 255, 235, 230, 240, 16, 255, 255, 255, 255, 236, 177, 247, 16, 255,
    255, 255, 255, 237, 198, 210, 16, 255, 255, 255, 255, 238, 145, 217, 16, 255,
    255, 255, 255, 239, 175, 238, 144, 255, 255, 255, 255, 240, 113, 187, 16, 255,
    255, 255, 255, 241, 143, 208, 144, 255, 255, 255, 255, 242, 127, 193, 144, 255,
    255, 255, 255, 243, 111, 178, 144, 255, 255, 255, 255, 244, 95, 163, 144, 255,
    255, 255, 255, 245, 79, 148, 144, 255, 255, 255, 255, 246, 63, 133, 144, 255,
    255, 255, 255, 247, 47, 118, 144, 255, 255, 255, 255, 248, 40, 162, 16, 255,
    255, 255, 255, 249, 15, 88, 144, 255, 255, 255, 255, 250, 8, 132, 16, 255, 255,
    255, 255, 250, 248, 131, 32, 255, 255, 255, 255, 251, 232, 102, 16, 255, 255,
    255, 255, 252, 216, 101, 32, 255, 255, 255, 255, 253, 200, 72, 16, 255, 255,
    255, 255, 254, 184, 71, 32, 255, 255, 255, 255, 255, 168, 42, 16, 0, 0, 0, 0,
    0, 152, 41, 32, 0, 0, 0, 0, 1, 136, 12, 16, 0, 0, 0, 0, 2, 120, 11, 32, 0, 0,
    0, 0, 3, 113, 40, 144, 0, 0, 0, 0, 4, 97, 39, 160, 0, 0, 0, 0, 5, 81, 10, 144,
    0, 0, 0, 0, 6, 65, 9, 160, 0, 0, 0, 0, 7, 48, 236, 144, 0, 0, 0, 0, 7, 141, 67,
    160, 0, 0, 0, 0, 9, 16, 206, 144, 0, 0, 0, 0, 9, 173, 191, 32, 0, 0, 0, 0, 10,
    240, 176, 144, 0, 0, 0, 0, 11, 224, 175, 160, 0, 0, 0, 0, 12, 217, 205, 16, 0,
    0, 0, 0, 13, 192, 145, 160, 0, 0, 0, 0, 14, 185, 175, 16, 0, 0, 0, 0, 15, 169,
    174, 32, 0, 0, 0, 0, 16, 153, 145, 16, 0, 0, 0, 0, 17, 137, 144, 32, 0, 0, 0,
    0, 18, 121, 115, 16, 0, 0, 0, 0, 19, 105, 114, 32, 0, 0, 0, 0, 20, 89, 85, 16,
    0, 0, 0, 0, 21, 73, 84, 32, 0, 0, 0, 0, 22, 57, 55, 16, 0, 0, 0, 0, 23, 41, 54,
    32, 0, 0, 0, 0, 24, 34, 83, 144, 0, 0, 0, 0, 25, 9, 24, 32, 0, 0, 0, 0, 26, 2,
    53, 144, 0, 0, 0, 0, 26, 242, 52, 160, 0, 0, 0, 0, 27, 226, 23, 144, 0, 0, 0,
    0, 28, 210, 22, 160, 0, 0, 0, 0, 29, 193, 249, 144, 0, 0, 0, 0, 30, 177, 248,
    160, 0, 0, 0, 0, 31, 161, 219, 144, 0, 0, 0, 0, 32, 118, 43, 32, 0, 0, 0, 0,
    33, 129, 189, 144, 0, 0, 0, 0, 34, 86, 13, 32, 0, 0, 0, 0, 35, 106, 218, 16,
    0, 0, 0, 0, 36, 53, 239, 32, 0, 0, 0, 0, 37, 74, 188, 16, 0, 0, 0, 0, 38, 21,
    209, 32, 0, 0, 0, 0, 39, 42, 158, 16, 0, 0, 0, 0, 39, 254, 237, 160, 0, 0, 0,
    0, 41, 10, 128, 16, 0, 0, 0, 0, 41, 222, 207, 160, 0, 0, 0, 0, 42, 234, 98, 16,
    0, 0, 0, 0, 43, 190, 177, 160, 0, 0, 0, 0, 44, 211, 126, 144, 0, 0, 0, 0, 45,
    158, 147, 160, 0, 0, 0, 0, 46, 179, 96, 144, 0, 0, 0, 0, 47, 126, 117, 160, 0,
    0, 0, 0, 48, 147, 66, 144, 0, 0, 0, 0, 49, 103, 146, 32, 0, 0, 0, 0, 50, 115,
    36, 144, 0, 0, 0, 0, 51, 71, 116, 32, 0, 0, 0, 0, 52, 83, 6, 144, 0, 0, 0, 0,
    53, 39, 86, 32, 0, 0, 0, 0, 54, 50, 232, 144, 0, 0, 0, 0, 55, 7, 56, 32, 0, 0,
    0, 0, 56, 28, 5, 16, 0, 0, 0, 0, 56, 231, 26, 32, 0, 0, 0, 0, 57, 251, 231, 16,
    0, 0, 0, 0, 58, 198, 252, 32, 0, 0, 0, 0, 59, 219, 201, 16, 0, 0, 0, 0, 60, 176,
    24, 160, 0, 0, 0, 0, 61, 187, 171, 16, 0, 0, 0, 0, 62, 143, 250, 160, 0, 0, 0,
    0, 63, 155, 141, 16, 0, 0, 0, 0, 64, 111, 220, 160, 0, 0, 0, 0, 65, 132, 169,
    144, 0, 0, 0, 0, 66, 79, 190, 160, 0, 0, 0, 0, 67, 100, 139, 144, 0, 0, 0, 0,
    68, 47, 160, 160, 0, 0, 0, 0, 69, 68, 109, 144, 0, 0, 0, 0, 69, 243, 211, 32,
    0, 0, 0, 0, 71, 45, 138, 16, 0, 0, 0, 0, 71, 211, 181, 32, 0, 0, 0, 0, 73, 13,
    108, 16, 0, 0, 0, 0, 73, 179, 151, 32, 0, 0, 0, 0, 74, 237, 78, 16, 0, 0, 0,
    0, 75, 156, 179, 160, 0, 0, 0, 0, 76, 214, 106, 144, 0, 0, 0, 0, 77, 124, 149,
    160, 0, 0, 0, 0, 78, 182, 76, 144, 0, 0, 0, 0, 79, 92, 119, 160, 0, 0, 0, 0,
    80, 150, 46, 144, 0, 0, 0, 0, 81, 60, 89, 160, 0, 0, 0, 0, 82, 118, 16, 144,
    0, 0, 0, 0, 83, 28, 59, 160, 0, 0, 0, 0, 84, 85, 242, 144, 0, 0, 0, 0, 84, 252,
    29, 160, 0, 0, 0, 0, 86, 53, 212, 144, 0, 0, 0, 0, 86, 229, 58, 32, 0, 0, 0,
    0, 88, 30, 241, 16, 0, 0, 0, 0, 88, 197, 28, 32, 0, 0, 0, 0, 89, 254, 211, 16,
    0, 0, 0, 0, 90, 164, 254, 32, 0, 0, 0, 0, 91, 222, 181, 16, 0, 0, 0, 0, 92, 132,
    224, 32, 0, 0, 0, 0, 93, 190, 151, 16, 0, 0, 0, 0, 94, 100, 194, 32, 0, 0, 0,
    0, 95, 158, 121, 16, 0, 0, 0, 0, 96, 77, 222, 160, 0, 0, 0, 0, 97, 135, 149,
    144, 0, 0, 0, 0, 98, 45, 192, 160, 0, 0, 0, 0, 99, 103, 119, 144, 0, 0, 0, 0,
    100, 13, 162, 160, 0, 0, 0, 0, 101, 71, 89, 144, 0, 0, 0, 0, 101, 237, 132, 160,
    0, 0, 0, 0, 103, 39, 59, 144, 0, 0, 0, 0, 103, 205, 102, 160, 0, 0, 0, 0, 105,
    7, 29, 144, 0, 0, 0, 0, 105, 173, 72, 160, 0, 0, 0, 0, 106, 230, 255, 144, 0,
    0, 0, 0, 107, 150, 101, 32, 0, 0, 0, 0, 108, 208, 28, 16, 0, 0, 0, 0, 109, 118,
    71, 32, 0, 0, 0, 0, 110, 175, 254, 16, 0, 0, 0, 0, 111, 86, 41, 32, 0, 0, 0,
    0, 112, 143, 224, 16, 0, 0, 0, 0, 113, 54, 11, 32, 0, 0, 0, 0, 114, 111, 194,
    16, 0, 0, 0, 0, 115, 21, 237, 32, 0, 0, 0, 0, 116, 79, 164, 16, 0, 0, 0, 0, 116,
    255, 9, 160, 0, 0, 0, 0, 118, 56, 192, 144, 0, 0, 0, 0, 118, 222, 235, 160, 0,
    0, 0, 0, 120, 24, 162, 144, 0, 0, 0, 0, 120, 190, 205, 160, 0, 0, 0, 0, 121,
    248, 132, 144, 0, 0, 0, 0, 122, 158, 175, 160, 0, 0, 0, 0, 123, 216, 102, 144,
    0, 0, 0, 0, 124, 126, 145, 160, 0, 0, 0, 0, 125, 184, 72, 144, 0, 0, 0, 0, 126,
    94, 115, 160, 0, 0, 0, 0, 127, 152, 42, 144, 5, 1, 2, 1, 2, 3, 4, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1,
    2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 255, 255, 145, 38, 0,
    0, 255, 255, 157, 144, 1, 4, 255, 255, 143, 128, 0, 8, 255, 255, 157, 144, 1,
    12, 255, 255, 157, 144, 1, 16, 255, 255, 143, 128, 0, 8, 76, 77, 84, 0, 80, 68,
    84, 0, 80, 83, 84, 0, 80, 87, 84, 0, 80, 80, 84, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0,
    0, 1, 1, 10, 80, 83, 84, 56, 80, 68, 84, 44, 77, 51, 46, 50, 46, 48, 44, 77,
    49, 49, 46, 49, 46, 48, 10,
  ]
  let name = "America/Los_Angeles"
  let zone = Zone::from_tzif(name, data)
  inspect(zone, content="America/Los_Angeles")
  let current_time_seconds = 1706659200L // Tuesday, January 30, 2024 4:00:00pm PST
  let got = unix(current_time_seconds, zone~)
  inspect(got, content="2024-01-30T16:00:00-08:00[PST]")
  inspect(got.offset(), content="-08:00")
  inspect(got.offset().is_dst(), content="false")
  let current_time_seconds = 1754006400L // Thursday, July 31, 2025 5:00:00pm PDT
  let got = unix(current_time_seconds, zone~)
  inspect(got, content="2025-07-31T17:00:00-07:00[PDT]")
  inspect(got.offset(), content="-07:00")
  inspect(got.offset().is_dst(), content="true")
  // Explicit transitions end in 2037; the footer still specifies summer DST.
  let future = unix(2224713600L, zone~) // 2040-07-01T00:00:00Z.
  inspect(future, content="2040-06-30T17:00:00-07:00[PDT]")
  // Behavior of a fixed-offset zone:
  let zone = fixed_zone(name, -25200, abbrev="PDT", dst=true)
  let got = unix(current_time_seconds, zone~)
  inspect(got, content="2025-07-31T17:00:00-07:00[PDT]")
  inspect(got.offset(), content="-07:00")
  inspect(got.offset().is_dst(), content="true")
}

///|
#deprecated
pub extend Zone with Eq::{not_equal, equal}

///|
#deprecated
pub extend Zone with Debug::{to_repr}

///|
#deprecated
pub extend Zone with Show::{output}

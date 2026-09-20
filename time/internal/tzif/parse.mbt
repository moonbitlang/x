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
priv struct Header {
  version : Version
  ut_count : Int
  standard_count : Int
  leap_count : Int
  transition_count : Int
  type_count : Int
  designation_count : Int
}

///|
// Return the header, its bounded data block, and the remaining file.
fn read_header(
  bytes : BytesView,
  width : Int,
  origin : Int,
) -> (Header, BytesView, BytesView) raise ParseError {
  let offset = bytes.start_offset() - origin
  guard bytes is [.. b"TZif", .. rest] else {
    raise ParseError(offset, "invalid magic")
  }
  guard rest
    is [
      version,
      u64be(_),
      u56be(_), // 15 reserved bytes.
      u32be(ut),
      u32be(standard),
      u32be(leaps),
      u32be(times),
      u32be(types),
      u32be(chars),
      .. rest,
    ] else {
    raise ParseError(offset, "truncated header")
  }
  let version = match version {
    b'\x00' => V1
    b'2' => V2
    b'3' => V3
    b'4' => V4
    _ => raise ParseError(offset + 4, "unsupported version")
  }
  // Widen before multiplication. Check the whole block before narrowing the
  // counts or splitting its sections, including the compatibility block.
  let length = times.to_uint64() * (width + 1).to_uint64() +
    types.to_uint64() * 6UL +
    chars.to_uint64() +
    leaps.to_uint64() * (width + 4).to_uint64() +
    standard.to_uint64() +
    ut.to_uint64()
  guard length <= rest.length().to_uint64() else {
    raise ParseError(offset + 20, "truncated data block or excessive counts")
  }
  let header : Header = {
    version,
    ut_count: ut.reinterpret_as_int(),
    standard_count: standard.reinterpret_as_int(),
    leap_count: leaps.reinterpret_as_int(),
    transition_count: times.reinterpret_as_int(),
    type_count: types.reinterpret_as_int(),
    designation_count: chars.reinterpret_as_int(),
  }
  let length = length.to_int()
  (header, rest[:length], rest[length:])
}

///|
fn read_time(
  bytes : BytesView,
  width : Int,
  origin : Int,
) -> (Int64, BytesView) raise ParseError {
  let offset = bytes.start_offset() - origin
  match width {
    4 => {
      guard bytes is [i32be(value), .. rest] else {
        raise ParseError(offset, "truncated timestamp")
      }
      (value.to_int64(), rest)
    }
    8 => {
      guard bytes is [i64be(value), .. rest] else {
        raise ParseError(offset, "truncated timestamp")
      }
      (value, rest)
    }
    _ => raise ParseError(offset, "invalid timestamp width")
  }
}

///|
/// Decode a complete TZif v1–v4 file as specified by RFC 9636.
/// Leap-bearing files are accepted and their timestamps and corrections are
/// preserved. This function does not convert timestamps to POSIX seconds,
/// evaluate recurring rules, or construct a `Zone`.
///
/// Validates structural constraints and footer syntax. It does not check that
/// leap occurrences fall at UTC month ends or that the footer agrees with the
/// last transition; those require interpreting the records.
pub fn parse(bytes : BytesView) -> Data raise ParseError {
  // Views carry their position in the backing bytes. Subtract the caller's
  // starting position only when reporting an error, including for subviews.
  let origin = bytes.start_offset()
  let (first, block, rest) = read_header(bytes, 4, origin)
  let (header, rest, footer, width) = if first.version == V1 {
    (first, block, rest, 4)
  } else {
    // RFC 9636 section 4: skip the compatibility block without decoding it.
    let (second, block, tail) = read_header(rest, 8, origin)
    guard second.version == first.version else {
      raise ParseError(
        rest.start_offset() - origin + 4,
        "headers disagree on version",
      )
    }
    (second, block, tail, 8)
  }
  let offset = rest.start_offset() - origin
  guard header.type_count > 0 && header.designation_count > 0 else {
    raise ParseError(offset - 8, "empty local time types or designations")
  }
  guard (header.ut_count == 0 || header.ut_count == header.type_count) &&
    (header.standard_count == 0 || header.standard_count == header.type_count) else {
    raise ParseError(
      offset - 24,
      "indicator counts must be zero or the type count",
    )
  }
  // The checked block length bounds each split. Keep independent views for
  // tables referenced by index; consume sequential records from their views.
  let (times, rest) = (
    rest[:header.transition_count * width],
    rest[header.transition_count * width:],
  )
  let (indices, rest) = (
    rest[:header.transition_count],
    rest[header.transition_count:],
  )
  let (types, rest) = (
    rest[:header.type_count * 6],
    rest[header.type_count * 6:],
  )
  let (designations, rest) = (
    rest[:header.designation_count],
    rest[header.designation_count:],
  )
  let (leaps, rest) = (
    rest[:header.leap_count * (width + 4)],
    rest[header.leap_count * (width + 4):],
  )
  let (standards, uts) = (
    rest[:header.standard_count],
    rest[header.standard_count:],
  )
  guard designations is [.., b'\x00'] else {
    raise ParseError(
      designations.start_offset() - origin + designations.length() - 1,
      "designations must end with NUL",
    )
  }
  let transitions : Array[Transition] = []
  for i = 0, rest = times; i < header.transition_count; {
    let offset = rest.start_offset() - origin
    let (time, rest) = read_time(rest, width, origin)
    guard i == 0 || time > transitions[i - 1].time else {
      raise ParseError(offset, "transition times must increase strictly")
    }
    let type_index = indices[i].to_int()
    guard type_index < header.type_count else {
      raise ParseError(
        indices.start_offset() - origin + i,
        "invalid transition type index",
      )
    }
    transitions.push({ time, type_index, })
    continue i + 1, rest
  }
  let local_time_types : Array[LocalTimeType] = []
  // At most 256 designation starts can be referenced. Cache them to avoid
  // repeatedly copying or scanning a long shared designation for every type.
  let names : FixedArray[Bytes?] = FixedArray::make(256, None)
  for i = 0, rest = types; i < header.type_count; {
    let offset = rest.start_offset() - origin
    guard rest is [i32be(utoff), u8be(dst), u8be(name_index), .. rest] else {
      raise ParseError(offset, "truncated local time type")
    }
    guard utoff != -2147483648 && dst <= 1U else {
      raise ParseError(offset, "invalid offset or DST indicator")
    }
    let name_index = name_index.reinterpret_as_int()
    guard name_index < designations.length() else {
      raise ParseError(offset + 5, "invalid designation index")
    }
    let designation = match names[name_index] {
      Some(name) => name
      None => {
        let name = designations[name_index:]
        let length = for rest = name {
          match rest {
            [b'\x00', ..] => break name.length() - rest.length()
            [_, .. rest] => continue rest
            [] =>
              raise ParseError(
                name.start_offset() - origin,
                "unterminated designation",
              )
          }
        }
        let name = name[:length].to_owned()
        names[name_index] = Some(name)
        name
      }
    }
    let standard = if standards.is_empty() { b'\x00' } else { standards[i] }
    let ut = if uts.is_empty() { b'\x00' } else { uts[i] }
    guard standard <= b'\x01' &&
      ut <= b'\x01' &&
      (ut == b'\x00' || standard == b'\x01') else {
      raise ParseError(
        standards.start_offset() - origin + i,
        "invalid standard/wall or UT/local indicator",
      )
    }
    local_time_types.push({
      offset: utoff,
      is_dst: dst == 1U,
      designation,
      is_standard: standard == b'\x01',
      is_ut: ut == b'\x01',
    })
    continue i + 1, rest
  }
  let leap_records : Array[LeapRecord] = []
  for i = 0, rest = leaps; i < header.leap_count; {
    let offset = rest.start_offset() - origin
    let (time, rest) = read_time(rest, width, origin)
    guard rest is [i32be(correction), .. rest] else {
      raise ParseError(offset + width, "truncated leap correction")
    }
    if i == 0 {
      guard time >= 0L else {
        raise ParseError(offset, "negative first leap occurrence")
      }
      guard header.version == V4 || correction == 1 || correction == -1 else {
        raise ParseError(
          offset + width,
          "truncated leap history requires version 4",
        )
      }
    } else {
      let previous = leap_records[i - 1]
      guard time > previous.time else {
        raise ParseError(offset, "leap occurrences must increase strictly")
      }
      let change = correction.to_int64() - previous.correction.to_int64()
      let expiration = header.version == V4 &&
        i == header.leap_count - 1 &&
        change == 0L
      guard change == 1L || change == -1L || expiration else {
        raise ParseError(offset + width, "invalid leap correction step")
      }
      // Month ends are at least 28 days apart, minus a possible negative leap.
      // Expiration is not a leap occurrence. Both times are nonnegative, so
      // subtracting them cannot overflow.
      guard expiration || time - previous.time >= 2419199L else {
        raise ParseError(offset, "leap occurrences are too close together")
      }
    }
    leap_records.push({ time, correction, })
    continue i + 1, rest
  }
  let future_rule = match (header.version, footer) {
    (V1, []) => None
    (V1, _) =>
      raise ParseError(
        footer.start_offset() - origin,
        "trailing data in version 1 file",
      )
    (_, [b'\n', .. rule, b'\n']) =>
      if rule.is_empty() {
        None
      } else {
        Some(parse_footer(rule, rule.start_offset() - origin, header.version))
      }
    _ =>
      raise ParseError(
        footer.start_offset() - origin,
        "missing newline-delimited footer",
      )
  }
  {
    version: header.version,
    transitions,
    local_time_types,
    leap_records,
    future_rule,
  }
}

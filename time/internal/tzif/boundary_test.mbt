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
// Synthetic inputs for boundary cases and malformed combinations absent from
// the RFC examples. The independent reference inputs are the verbatim bytes in
// fixtures_test.mbt (RFC 9636 Appendix B), exercised by parse_test.mbt.
fn fixture(
  version? : Byte = b'4',
  transitions? : Array[(Int64, Int)] = [],
  types? : Array[(Int, Int, Int)] = [(0, 0, 0)],
  names? : Bytes = b"UTC\x00",
  leaps? : Array[(Int64, Int)] = [],
  standards? : Bytes = b"",
  uts? : Bytes = b"",
  footer? : Bytes = b"UTC0",
) -> Bytes {
  let out = @buffer.Buffer()
  if version != b'\x00' {
    // The RFC's placeholder compatibility block has no transitions or leaps.
    out.write_bytes(
      Bytes::makei(51, i => if i == 4 { version } else { rfc_b5[i] }),
    )
  }
  out.write_bytes(b"TZif")
  out.write_byte(version)
  out.write_bytes(Bytes::makei(15, _ => b'\x00'))
  for
    count in [
      uts.length(),
      standards.length(),
      leaps.length(),
      transitions.length(),
      types.length(),
      names.length(),
    ] {
    out.write_int_be(count)
  }
  for (time, _) in transitions {
    if version == b'\x00' {
      out.write_int_be(time.to_int())
    } else {
      out.write_int64_be(time)
    }
  }
  for (_, index) in transitions {
    out.write_byte(index.to_byte())
  }
  for (offset, dst, index) in types {
    out.write_int_be(offset)
    out.write_byte(dst.to_byte())
    out.write_byte(index.to_byte())
  }
  out.write_bytes(names)
  for (time, correction) in leaps {
    if version == b'\x00' {
      out.write_int_be(time.to_int())
    } else {
      out.write_int64_be(time)
    }
    out.write_int_be(correction)
  }
  out.write_bytes(standards)
  out.write_bytes(uts)
  if version != b'\x00' {
    out.write_byte(b'\n')
    out.write_bytes(footer)
    out.write_byte(b'\n')
  }
  out.to_bytes()
}

///|
test "64-bit transitions, wide offsets, and designation suffixes are preserved" {
  let file = fixture(
    transitions=[
      (-9223372036854775808L, 0),
      (-2147483649L, 1),
      (2147483648L, 0),
      (9223372036854775807L, 1),
    ],
    types=[(-89999, 0, 0), (93599, 1, 1)],
    names=b"xABC\x00",
    footer=b"",
  )
  let data = @tzif.parse(file)
  assert_eq(data.transitions[0].time, -9223372036854775808L)
  assert_eq(data.transitions[3].time, 9223372036854775807L)
  assert_eq(data.local_time_types[0].offset, -89999)
  assert_eq(data.local_time_types[1].offset, 93599)
  assert_eq(data.local_time_types[1].designation, b"ABC")
  assert_eq(data.future_rule, None)
  let legacy = @tzif.parse(fixture(names=b"\xff\x00"))
  assert_eq(legacy.local_time_types[0].designation, b"\xff")
  let empty = @tzif.parse(fixture(names=b"\x00"))
  assert_eq(empty.local_time_types[0].designation, b"")
}

///|
test "positive and negative leap corrections are retained in every version" {
  for version in [b'\x00', b'2', b'3', b'4'] {
    for
      leaps in [
        [(78796800L, 1), (94694400L, 0)],
        [(78796799L, -1), (94694399L, 0)],
      ] {
      let data = @tzif.parse(fixture(version~, leaps~))
      assert_eq(data.leap_records.length(), 2)
      for i in 0..<leaps.length() {
        assert_eq(data.leap_records[i].time, leaps[i].0)
        assert_eq(data.leap_records[i].correction, leaps[i].1)
      }
    }
  }
}

///|
test "successive leap occurrences require at least 28 days minus one second" {
  for version in [b'\x00', b'2', b'3', b'4'] {
    for correction in [0, 2] {
      for gap in [1L, 2419198L] {
        @test.assert_raise(() => {
          @tzif.parse(
            fixture(version~, leaps=[
              (78796800L, 1),
              (78796800L + gap, correction),
            ]),
          )
        })
      }
      for gap in [2419199L, 2419200L] {
        let data = @tzif.parse(
          fixture(version~, leaps=[
            (78796800L, 1),
            (78796800L + gap, correction),
          ]),
        )
        assert_eq(data.leap_records[1].time, 78796800L + gap)
      }
    }
  }
  // Expiration records are not leap occurrences and need only increase.
  let expires = @tzif.parse(fixture(leaps=[(78796800L, 1), (78796801L, 1)]))
  assert_eq(expires.leap_records[1].time, 78796801L)
  let wide = @tzif.parse(fixture(leaps=[(0L, 1), (9223372036854775807L, 2)]))
  assert_eq(wide.leap_records[1].time, 9223372036854775807L)
}

///|
test "type counts are not limited by the width of transition indices" {
  // RFC 9636 section 3.1 specifies a nonzero u32 count, not a 256-record limit.
  // Extra, unreferenced records remain part of the decoded file.
  for count in [255, 256, 257] {
    let index = if count == 255 { 254 } else { 255 }
    let data = @tzif.parse(
      fixture(types=Array::makei(count, i => (i, 0, 0)), transitions=[
        (0L, index),
      ]),
    )
    assert_eq(data.local_time_types.length(), count)
    assert_eq(data.local_time_types[count - 1].offset, count - 1)
    assert_eq(data.transitions[0].type_index, index)
  }
}

///|
test "v4 truncation and expiration are data, not a reason to reject the file" {
  let leaps = [(1483228826L, 27), (1735344027L, 27)]
  let data = @tzif.parse(fixture(leaps~))
  assert_eq(data.leap_records[0].correction, 27)
  assert_eq(data.leap_records[1].correction, 27)
  assert_eq(data.leap_records[1].time, 1735344027L)
  for correction in [0, -27, 2147483647, -2147483648] {
    let truncated = @tzif.parse(fixture(leaps=[(1483228826L, correction)]))
    assert_eq(truncated.leap_records[0].correction, correction)
  }
  for version in [b'\x00', b'2', b'3'] {
    @test.assert_raise(() => @tzif.parse(fixture(version~, leaps~)))
    @test.assert_raise(() => {
      @tzif.parse(fixture(version~, leaps=[(78796800L, 1), (94694401L, 1)]))
    })
  }
}

///|
test "reject malformed records and cross-record constraints" {
  let files = [
    fixture(types=[]),
    fixture(names=b""),
    fixture(names=b"UTC"),
    fixture(types=[(-2147483648, 0, 0)]),
    fixture(types=[(0, 2, 0)]),
    fixture(types=[(0, 0, 4)]),
    fixture(transitions=[(0L, 1)]),
    fixture(transitions=[(1L, 0), (1L, 0)]),
    fixture(transitions=[(1L, 0), (0L, 0)]),
    fixture(standards=b"\x00\x00"),
    fixture(uts=b"\x00\x00"),
    fixture(standards=b"\x02"),
    fixture(standards=b"\x01", uts=b"\x02"),
    fixture(uts=b"\x01"),
    fixture(leaps=[(-1L, 1)]),
    fixture(leaps=[(78796800L, 1), (78796800L, 2)]),
    fixture(leaps=[(78796800L, 1), (78796799L, 2)]),
    fixture(leaps=[(78796800L, 1), (94694401L, 3)]),
    fixture(leaps=[(78796800L, 1), (94694401L, 1), (126230401L, 2)]),
    fixture(leaps=[(78796800L, 2147483647), (94694401L, -2147483648)]),
    fixture(version=b'\x00') + b"extra",
    fixture() + b"extra",
  ]
  for file in files {
    @test.assert_raise(() => @tzif.parse(file))
  }
}

///|
test "reject oversized counts and invalid headers before allocation" {
  for start in [0, 51] {
    for field in [20, 24, 28, 32, 36, 40] {
      for
        value in [b"\xff\xff\xff\xff", b"\x80\x00\x00\x00", b"\x40\x00\x00\x00"] {
        let file = fixture()
        let changed = Bytes::makei(file.length(), i => {
          if i >= start + field && i < start + field + 4 {
            value[i - start - field]
          } else {
            file[i]
          }
        })
        @test.assert_raise(() => @tzif.parse(changed))
      }
    }
    for (field, value) in [(0, b'X'), (4, b'1'), (4, b'5'), (4, b'\xff')] {
      let file = fixture()
      let changed = Bytes::makei(file.length(), i => {
        if i == start + field {
          value
        } else {
          file[i]
        }
      })
      @test.assert_raise(() => @tzif.parse(changed))
    }
  }
  let file = fixture()
  let mismatched = Bytes::makei(file.length(), i => {
    if i == 55 {
      b'2'
    } else {
      file[i]
    }
  })
  @test.assert_raise(() => @tzif.parse(mismatched))
}

///|
test "compatibility records are ignored and BytesView offsets are respected" {
  let file = fixture()
  let changed = Bytes::makei(file.length(), i => {
    if i == 48 {
      b'\xff'
    } else {
      file[i]
    }
  })
  assert_eq(@tzif.parse(changed), @tzif.parse(file))
  let padded = b"prefix" + file + b"suffix"
  assert_eq(@tzif.parse(padded[6:6 + file.length()]), @tzif.parse(file))
}

///|
test "error offsets are relative to the supplied view" {
  let cases = [
    (fixture(version=b'5'), 4),
    (rfc_b5[:51].to_owned(), 51),
    (fixture(types=[(0, 2, 0)]), 95),
    (fixture(transitions=[(0L, 1)]), 103),
    (fixture(leaps=[(-1L, 1)]), 105),
    (fixture(footer=b"UTC"), 109),
  ]
  for (file, expected_offset) in cases {
    let padded = b"prefix" + file + b"suffix"
    for view in [file[:], padded[6:6 + file.length()]] {
      try @tzif.parse(view) catch {
        ParseError(offset, _) => assert_eq(offset, expected_offset)
      } noraise {
        _ => fail("expected invalid TZif")
      }
    }
  }
}

///|
test "mutation smoke test never panics" {
  for file in [rfc_b1, rfc_b2, rfc_b3, rfc_b4, rfc_b5] {
    for offset in 0..<file.length() {
      for value in [b'\x00', b'\x01', b'\x7f', b'\x80', b'\xff'] {
        let changed = Bytes::makei(file.length(), i => {
          if i == offset {
            value
          } else {
            file[i]
          }
        })
        try @tzif.parse(changed) catch {
          _ => ()
        } noraise {
          _ => ()
        }
      }
    }
  }
}

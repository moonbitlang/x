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
#warnings("-deprecated")
test "from_tzif accepts every format version and borrowed byte views" {
  for version in [b'\x00', b'2', b'3', b'4'] {
    // Construct a fixed UTC file. With no transitions or leap records, the
    // 32-bit and 64-bit blocks have the same layout; v2+ contains both.
    let file = @buffer.Buffer()
    for _ in 0..<(if version == b'\x00' { 1 } else { 2 }) {
      file.write_bytes(b"TZif")
      file.write_byte(version)
      file.write_bytes(Bytes::make(15, b'\x00')) // Reserved header bytes.
      file.write_int_be(0) // UT/local indicators.
      file.write_int_be(0) // Standard/wall indicators.
      file.write_int_be(0) // Leap records.
      file.write_int_be(0) // Transitions.
      file.write_int_be(1) // Local time types.
      file.write_int_be(4) // Designation bytes including NUL.
      file.write_int_be(0) // UTC offset in seconds.
      file.write_byte(b'\x00') // Standard time.
      file.write_byte(b'\x00') // Index of "UTC" in the designation table.
      file.write_bytes(b"UTC\x00")
    }
    if version != b'\x00' {
      file.write_bytes(b"\nUTC0\n")
    }
    let bytes = file.to_bytes()
    let zone = @time.Zone::from_tzif("UTC", bytes)
    let padded = b"prefix" + bytes + b"suffix"
    assert_eq(@time.Zone::from_tzif("UTC", padded[6:6 + bytes.length()]), zone)
    assert_eq(zone, @time.utc_zone)
    assert_true(zone.is_fixed())
    let date_time = @time.unix(0L, zone~)
    assert_eq(date_time.offset().seconds(), 0)
    assert_eq(date_time.offset().abbreviation(), "UTC")
    assert_false(date_time.offset().is_dst())
    // Existing FixedArray callers retain a deprecated compatibility entry.
    assert_eq(@time.Zone::from_tzif2("UTC", bytes.to_fixedarray()), zone)
  }
}

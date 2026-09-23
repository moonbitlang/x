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
test "transition lookup preserves table order at every boundary" {
  let offsets = [
    ZoneOffset::from_seconds(3600, abbrev="Initial"),
    ZoneOffset::from_seconds(0),
    ZoneOffset::from_seconds(3600, abbrev="Later", dst=true),
  ]
  for count in [0, 1, 2, 3, 16, 17, 256, 257] {
    let zone : Zone = {
      id: "Lookup boundaries",
      offsets,
      // Leap projection can give several records the same Unix second.
      transitions: Array::makei(count, i => ((i / 3 - 20).to_int64(), i % 3)),
      past: None,
      future: None,
    }
    for second in -21L..<=67L {
      // The original table-order definition serves as the oracle, including
      // the initial type, empty tables, duplicate timestamps, and metadata.
      let mut expected = offsets[0]
      for (time, index) in zone.transitions {
        if time <= second {
          expected = offsets[index]
        }
      }
      assert_eq(zone.lookup_offset(second), expected)
    }
  }
}

///|
test "bench local construction with many TZif types and transitions" (
  it : @bench.T,
) {
  for count in [1024, 4096] {
    // These decoded records describe a valid TZif: only types 0 and 1 are
    // referenced, but the u32 type count can retain many duplicate types.
    let zone = Zone::from_tzif_data("Large history", {
      ..tzif_example,
      local_time_types: Array::makei(count, i => {
        tzif_example.local_time_types[i % 2]
      }),
      transitions: Array::makei(count, i => {
        time: i.to_int64() * 86400L,
        type_index: i % 2,
      }),
    })
    let value = ZonedDateTime::of(2040, 1, 1, zone~)
    assert_eq(value.offset, zone.offsets[1])
    it.bench(name="\{count} types and transitions", fn() {
      it.keep(ZonedDateTime::of(2040, 1, 1, zone~) catch { _ => panic() })
    })
  }
}

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
#cfg(any(target="wasm", all(target="native", platform="windows")))
fn WindowsTimezone::to_zone(
  windows : WindowsTimezone,
  name : String,
  dynamic_disabled : Bool,
) -> Zone raise Error {
  let id = if name.is_empty() { "local" } else { name }
  let (first_year, rules) = if dynamic_disabled || name.is_empty() {
    // Disabling dynamic DST keeps the current rule; its transition dates
    // determine whether DST itself is disabled.
    (None, [windows.current_rule()])
  } else {
    let years : FixedArray[UInt32] = [0U, 0U]
    let error = windows.effective_years(years)
    if error == 2U { // ERROR_FILE_NOT_FOUND: no historical year range.
      (None, [windows.current_rule()])
    } else {
      guard error == 0U else {
        raise local_zone_error(
          error,
          "read Windows timezone year range for \{id}",
        )
      }
      let first = years[0]
      let last = years[1]
      guard first >= 1U && first <= last && last <= 65535U else {
        fail("Invalid Windows timezone year range")
      }
      let rules = Array(capacity=(last - first + 1U).reinterpret_as_int())
      for year in first..<=last {
        let error = windows.rule_for_year(year.reinterpret_as_int())
        guard error == 0U else {
          raise local_zone_error(
            error,
            "GetTimeZoneInformationForYear(\{year}, \{id})",
          )
        }
        // Copy fields into immutable MoonBit values before fetching another year.
        rules.push(windows.read_rule())
      }
      (Some(first.reinterpret_as_int()), rules)
    }
  }
  Zone::from_windows_rules(id, first_year, rules)
}

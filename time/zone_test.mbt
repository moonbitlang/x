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

test "fixed" {
  inspect!(@time.fixed_zone!("CST", 8 * 60 * 60), content="CST")
  inspect!(@time.fixed_zone!("CST", 8 * 60 * 60).is_fixed(), content="true")
}

test "utc" {
  inspect!(@time.utc_zone, content="UTC")
}

test "@time.fixed_zone_unvalidated/valid_offset" {
  let now = 1737643180L
  let zone = @time.fixed_zone_unvalidated("UTC+8", 8 * 3600)
  let zdt = @time.unix!(now, zone~)
  inspect!(zdt.to_string(), content="2025-01-23T22:39:40+08:00[UTC+8]")
  let zone = @time.fixed_zone_unvalidated("GMT", 3600)
  let zdt_gmt = @time.unix!(now, zone~)
  inspect!(zdt_gmt.to_string(), content="2025-01-23T15:39:40+01:00[GMT]")
  let zone = @time.fixed_zone_unvalidated("EST", -18000)
  let zdt_est = @time.unix!(now, zone~)
  inspect!(zdt_est.to_string(), content="2025-01-23T09:39:40-05:00[EST]")
  let zone = @time.fixed_zone_unvalidated("MinBoundary", -64800)
  let zdt = @time.unix!(now, zone~)
  inspect!(zdt.to_string(), content="2025-01-22T20:39:40-18:00[MinBoundary]")
  let zone = @time.fixed_zone_unvalidated("MaxBoundary", 64800)
  let zdt = @time.unix!(now, zone~)
  inspect!(zdt.to_string(), content="2025-01-24T08:39:40+18:00[MaxBoundary]")
}

test "@time.fixed_zone_unvalidated/invalid_offset" {
  let now = 1737643180L
  let zone = @time.fixed_zone_unvalidated("Invalid", 999999)
  let zdt = @time.unix!(now, zone~)
  inspect!(zdt.to_string(), content="2025-01-23T14:39:40Z")
  let zone = @time.fixed_zone_unvalidated("", 0)
  let zdt = @time.unix!(now, zone~)
  inspect!(zdt.to_string(), content="2025-01-23T14:39:40Z")
}

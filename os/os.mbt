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
/// Return the number of online logical CPUs, falling back to 1 if it cannot be
/// determined. This does not account for process affinity or CPU quotas; callers
/// may need to apply their own concurrency limit.
pub fn online_cpu_count() -> Int {
  let count = @ffi.online_cpu_count()
  if count > 0 {
    count
  } else {
    1
  }
}

///|
/// Read the monotonic clock in nanoseconds, raising OSError if it is unavailable.
/// Its origin is unspecified; use differences between readings to measure elapsed
/// time. Nanosecond units do not imply nanosecond resolution.
pub fn monotonic_now_ns() -> Int64 raise @os_error.OSError {
  let value = @ffi.monotonic_now_ns()
  if value < 0 {
    @os_error.check_errno("monotonic_now_ns")
  }
  value
}

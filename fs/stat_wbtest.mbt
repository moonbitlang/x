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
#cfg(any(target="native", target="js", target="wasm"))
test "Windows file identity rejects an unknown volume and reserved indices" {
  for (volume, index) in [(0L, 42L), (7L, 0L), (7L, -1L)] {
    assert_true(FileIdentity::from_stat(volume, index, windows=true) is None)
  }
  assert_true(FileIdentity::from_stat(0, 42, windows=false) is Some(_))
  assert_true(FileIdentity::from_stat(7, -2, windows=true) is Some(_))
}

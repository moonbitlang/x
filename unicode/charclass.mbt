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
/// A set of character ranges.
///
/// BMP membership is expanded into a bitset for constant-time lookup, and
/// supplementary (astral) ranges are kept sorted and flat for binary search.
/// The ranges passed to `of` must be sorted in ascending order and
/// non-overlapping.
pub struct CharClass {
  bmp : FixedArray[Int]
  astral : FixedArray[Int]
}

///|
pub fn CharClass::of(array : Array[(Char, Char)]) -> CharClass {
  let bmp = FixedArray::make(0x10000 / 32, 0)
  let astral : Array[Int] = []
  for item in array {
    let (min, max) = item
    let lo = min.to_int()
    let hi = max.to_int()
    if lo <= 0xFFFF {
      fill_bmp(bmp, lo, if hi < 0x10000 { hi } else { 0xFFFF })
    }
    if hi > 0xFFFF {
      astral.push(if lo < 0x10000 { 0x10000 } else { lo })
      astral.push(hi)
    }
  }
  { bmp, astral: FixedArray::from_array(astral) }
}

///|
fn fill_bmp(bmp : FixedArray[Int], a : Int, b : Int) -> Unit {
  let mut w = a >> 5
  let last = b >> 5
  if w == last {
    bmp[w] = bmp[w] | mask_between(a & 31, b & 31)
  } else {
    bmp[w] = bmp[w] | (-1 ^ low_mask(a & 31))
    w += 1
    while w < last {
      bmp[w] = -1
      w += 1
    }
    bmp[last] = bmp[last] | low_mask((b & 31) + 1)
  }
}

///|
/// A bitmask with the lowest `bits` bits set, where `0 <= bits <= 32`.
fn low_mask(bits : Int) -> Int {
  if bits == 32 {
    -1
  } else {
    (1 << bits) - 1
  }
}

///|
/// A bitmask with bits `lo..=hi` set, where `0 <= lo <= hi <= 31`.
fn mask_between(lo : Int, hi : Int) -> Int {
  (-1 ^ low_mask(lo)) & low_mask(hi + 1)
}

///|
pub fn CharClass::contains(self : CharClass, c : Char) -> Bool {
  let cc = c.to_int()
  if cc <= 0xFFFF {
    ((self.bmp[cc >> 5] >> (cc & 31)) & 1) == 1
  } else {
    for left = 0, right = self.astral.length() / 2; left < right; {
      let middle = (left + right) / 2
      let min = self.astral[middle * 2]
      if cc < min {
        continue left, middle
      } else if cc > self.astral[middle * 2 + 1] {
        continue middle + 1, right
      } else {
        break true
      }
    } nobreak {
      false
    }
  }
}

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

/// Converts a byte array to a hex string, without any prefix like "0x".
pub fn bytes_to_hex_string(input : Bytes) -> String {
  let mut ret = ""
  for i = input.length() - 1; i >= 0; i = i - 1 {
    let byte = input[i]
    let high = byte.to_int().lsr(4).land(0xf)
    let low = byte.to_int().land(0xf)
    let high_char = to_hex_char(high)
    let low_char = to_hex_char(low)
    ret = high_char + low_char + ret
  }
  ret
}

fn to_hex_char(n : Int) -> String {
  match n {
    0 => "0"
    1 => "1"
    2 => "2"
    3 => "3"
    4 => "4"
    5 => "5"
    6 => "6"
    7 => "7"
    8 => "8"
    9 => "9"
    10 => "a"
    11 => "b"
    12 => "c"
    13 => "d"
    14 => "e"
    15 => "f"
    _ => abort("invalid hex digit")
  }
}

fn rotate_left(x : Int, n : Int) -> Int {
  x.lsl(n).lor(x.lsr(32 - n))
}

fn rotate_left_u(x : UInt, n : Int) -> UInt {
  x.lsl(n) | x.lsr(32 - n)
}

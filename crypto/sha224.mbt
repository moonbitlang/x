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

///|
pub fn sha224(data : Bytes) -> Bytes {
  let ctx = Sha256Context::new(
    reg=[
      0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7,
      0xbefa4fa4,
    ],
  )
  let _ = ctx.update(data)
  arr_u32_to_u8be(ctx.sha256_compute().iter().take(7), 224)
}

///|
pub fn sha224_from_iter(data : Iter[Byte]) -> Bytes {
  let ctx = Sha256Context::new(
    reg=[
      0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7,
      0xbefa4fa4,
    ],
  )
  let _ = ctx.update_from_iter(data)
  arr_u32_to_u8be(ctx.sha256_compute().iter().take(7), 224)
}

test {
  // Sha224
  assert_eq!(
    bytes_to_hex_string(sha224(b"\x61\x62\x63")),
    "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
  )
  assert_eq!(
    bytes_to_hex_string(
      sha224(
        b"\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64\x61\x62\x63\x64",
      ),
    ),
    "fffd3b5e90c6fc3cb77c3d04b1f7660b16a426ef6655384e8486ae1f",
  )
}

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
#cfg(any(target="native", target="wasm"))
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  let simd_end = length / 16 * 16
  let vector_mask = @v128.i8x16_splat(mask)
  for offset = 0; offset < simd_end; offset = offset + 16 {
    @v128.v128_load(bytes, offset)
    |> @v128.v128_xor(vector_mask)
    |> value => { @v128.v128_store(bytes, offset, value) }
  }
  for offset in simd_end..<length {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

///|
#cfg(not(any(target="native", target="wasm")))
fn xor_bytes_with_splat_in_place(
  bytes : FixedArray[Byte],
  length : Int,
  mask : Byte,
) -> Unit {
  for offset in 0..<length {
    bytes.unsafe_set(offset, bytes.unsafe_get(offset) ^ mask)
  }
}

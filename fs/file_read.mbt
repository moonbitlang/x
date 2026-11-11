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
const STREAM_CHUNK_SIZE : Int32 = 4096

///|
const GROWING_FILE_CHUNK_SIZE : Int32 = 65536

///|
/// Shared by the new File API and the legacy Wasm stream reader.
/// Adapt async's File.read_all and io.read_all: size hint, EOF probe, retained
/// chunks, then one final allocation. Never treat metadata as proof of EOF.
/// The retained-chunk implementation is shared with the #361 Wasm adapter.
fn read_all_with_hint(
  read : (FixedArray[Byte], Int32) -> Int32 raise,
  size_hint : Int32?,
) -> Bytes raise {
  let chunks : Array[(FixedArray[Byte], Int32)] = []
  let mut total = 0
  if size_hint is Some(size) {
    let buffer : FixedArray[Byte] = FixedArray::make(size, 0)
    let n = read(buffer, 0)
    if n == 0 {
      return b""
    }
    let probe : FixedArray[Byte] = FixedArray::make(1, 0)
    if read(probe, 0) == 0 {
      // Only this reader owns the mutable buffer; ownership can be transferred.
      return buffer.unsafe_reinterpret_as_bytes()[:n].to_owned()
    }
    chunks.push((buffer, n))
    chunks.push((probe, 1))
    total = n + 1
  }
  let chunk_size = if size_hint is Some(_) {
    GROWING_FILE_CHUNK_SIZE
  } else {
    STREAM_CHUNK_SIZE
  }
  let mut buffer : FixedArray[Byte] = FixedArray::make(chunk_size, 0)
  let mut offset = 0
  while read(buffer, offset) is n && n > 0 {
    guard n <= MAX_FILE_BYTES - total else {
      raise Failure::Failure("file too large for Bytes")
    }
    offset += n
    total += n
    if offset == chunk_size {
      chunks.push((buffer, offset))
      buffer = FixedArray::make(chunk_size, 0)
      offset = 0
    }
  }
  if offset > 0 {
    chunks.push((buffer, offset))
  }
  let result : FixedArray[Byte] = FixedArray::make(total, 0)
  for (chunk, len) in chunks; offset = 0 {
    result.unsafe_blit(offset, chunk, 0, len)
    continue offset + len
  }
  result.unsafe_reinterpret_as_bytes()
}

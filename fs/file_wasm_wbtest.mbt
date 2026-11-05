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
#cfg(target="wasm")
test "read_all tolerates growth shrinkage and an empty size hint" {
  let path = "tmp_fs_wasm_size_hint"
  write_bytes_to_file_internal(path, b"")
  defer remove_file_internal(path)
  let chunk = GROWING_FILE_CHUNK_SIZE
  for
    (before, after) in [
      (chunk, chunk),
      (chunk, chunk - 1),
      (chunk, chunk + 1),
      (chunk, 2 * chunk + 17),
      (chunk, 0),
      (0, chunk + 1),
    ] {
    write_bytes_to_file_internal(path, Bytes::make(before, 0))
    let handle = open_handle(path, false)
    defer ignore(file_close_ffi(handle))
    let hint = handle.size_hint()
    assert_eq(hint, if before > 0 { Some(before) } else { None })
    // Mutate through another handle after stat, before reading.
    let contents = Bytes::makei(after, i => (i % 251).to_byte())
    write_bytes_to_file_internal(path, contents)
    assert_eq(handle.read_all(path, hint), contents)
  }
}

///|
#cfg(target="wasm")
test "read_all streams without metadata and combines chunks in order" {
  let path = "tmp_fs_wasm_no_size_hint"
  write_bytes_to_file_internal(path, b"")
  defer remove_file_internal(path)
  let chunk = STREAM_CHUNK_SIZE
  for len in [0, 1, chunk - 1, chunk, chunk + 1, 2 * chunk, 2 * chunk + 17] {
    let contents = Bytes::makei(len, i => (i % 251).to_byte())
    write_bytes_to_file_internal(path, contents)
    let handle = open_handle(path, false)
    defer ignore(file_close_ffi(handle))
    assert_eq(handle.read_all(path, None), contents)
  }
}

///|
#cfg(target="wasm")
test "read failures include the path and decoded OS error" {
  let path = "tmp_fs_wasm_read_error"
  let handle = open_handle(path, true)
  defer remove_file_internal(path)
  defer ignore(file_close_ffi(handle))
  // Reading a write-only handle fails at read on every supported host.
  let message = try {
    ignore(handle.read_all(path, None))
    fail("reading a write-only file should fail")
  } catch {
    IOError(message) => message
    error => raise error
  }
  assert_true(message.contains("read \{path}: "))
  assert_false(message.contains("OS error "))
  assert_true(message.split(": ").last().unwrap().length() > 0)
}

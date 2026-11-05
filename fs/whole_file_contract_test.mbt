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
fn file_test_path() -> String {
  let suffix = match @env.rand(8) {
    Some(random) => [ for byte in random => byte.to_hex() ].join("")
    None => "legacy_gc"
  }
  "tmp_fs_file_\{@env.now()}_\{suffix}.bin"
}

///|
test "whole-file overwrite and UTF-8 contract" {
  let path = file_test_path() + "_中文"
  @fs.write_bytes_to_file(path, b"long contents")
  defer (@fs.remove_file(path) catch { _ => () })
  @fs.write_bytes_to_file(path, b"\xff\x00a")
  debug_inspect(
    @fs.read_file_to_bytes(path),
    content="<Bytes: [0xff, 0x00, 0x61]>",
  )
  assert_eq(@fs.read_file_to_string(path), "\ufffd\u0000a")
  @fs.write_string_to_file(path, "月亮🌙")
  assert_eq(@fs.read_file_to_string(path), "月亮🌙")
  @fs.write_bytes_to_file(path, b"")
  assert_eq(@fs.read_file_to_bytes(path), b"")
  @fs.write_bytes_to_file(path, b"preserve on invalid encoding")
  @test.assert_raise(() => {
    @fs.write_string_to_file(path, "ignored", encoding="utf16")
  })
  assert_eq(@fs.read_file_to_bytes(path), b"preserve on invalid encoding")
  @test.assert_raise(() => @fs.read_file_to_string(path, encoding="utf16"))
  @test.assert_raise(() => @fs.read_file_to_bytes(path + ".missing"))
}

///|
test "whole-file reads return all contents across chunk boundaries" {
  let path = file_test_path()
  @fs.write_bytes_to_file(path, b"")
  defer (@fs.remove_file(path) catch { _ => () })
  let chunk_size = 64 * 1024
  // Below, at, and above a chunk boundary; then multiple chunks and a tail.
  for
    len in [
      0,
      1,
      chunk_size - 1,
      chunk_size,
      chunk_size + 1,
      2 * chunk_size,
      2 * chunk_size + 17,
    ] {
    let content = Bytes::from_array([ for i in 0..<len => (i % 251).to_byte() ])
    @fs.write_bytes_to_file(path, content)
    assert_eq(@fs.read_file_to_bytes(path), content)
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
test "native special-file and NUL-path compatibility" {
  assert_eq(@fs.read_file_to_bytes("/dev/null"), b"")
  @fs.write_bytes_to_file("/dev/null", b"discard")
  let path = file_test_path()
  @fs.write_bytes_to_file(path + "\u0000suffix", b"legacy")
  defer (@fs.remove_file(path) catch { _ => () })
  assert_eq(@fs.read_file_to_bytes(path + "\u0000suffix"), b"legacy")
}

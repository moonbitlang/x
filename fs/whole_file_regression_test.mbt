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
#cfg(all(target="native", not(platform="windows")))
test "failed native directory reads do not leak descriptors" {
  let before = @fs.read_dir("/dev/fd").length()
  // Each failed call used to leak one descriptor; repeat to check cleanup.
  for _ in 0..<3 {
    @test.assert_raise(() => @fs.read_file_to_bytes("."))
  }
  assert_eq(@fs.read_dir("/dev/fd").length(), before)
}

///|
#cfg(any(target="native", target="wasm"))
test "whole-file errors retain operation path and OS explanation" {
  let path = file_test_path()
  @fs.create_dir(path)
  defer @fs.remove_dir(path)
  for
    (operation, run) in [
      ("open", () => ignore(@fs.read_file_to_bytes(path + "/missing"))),
      ("open", () => @fs.write_bytes_to_file(path, b"not a regular file")),
    ] {
    let IOError(message) = @test.expect_error(run)
    assert_true(message.contains(operation))
    assert_true(message.contains(path))
    // OS wording/localization varies. Reject the previous numeric-only text.
    assert_false(message.contains("OS error "))
    let explanation = message.split(": ").last().unwrap()
    assert_true(explanation.length() > 0)
    assert_true(
      explanation
      .iter()
      .any(ch => {
        (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch > '\u{7f}'
      }),
    )
  }
}

///|
#cfg(all(target="native", not(platform="windows")))
const RLIMIT_FSIZE : Int32 = 1

///|
#cfg(all(target="native", not(platform="windows")))
const SIGXFSZ : Int32 = 25

///|
#cfg(all(target="native", not(platform="windows")))
const SIG_IGN : UInt64 = 1

///|
#cfg(all(target="native", not(platform="windows")))
const SIG_ERR : UInt64 = 0xffffffffffffffff

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(limits)
extern "C" fn getrlimit(resource : Int32, limits : FixedArray[UInt64]) -> Int32 = "getrlimit"

///|
#cfg(all(target="native", not(platform="windows")))
#borrow(limits)
extern "C" fn setrlimit(resource : Int32, limits : FixedArray[UInt64]) -> Int32 = "setrlimit"

///|
#cfg(all(target="native", not(platform="windows")))
extern "C" fn signal_handler(signal : Int32, handler : UInt64) -> UInt64 = "signal"

///|
#cfg(all(target="native", not(platform="windows")))
test "partial write failure closes the file and preserves diagnostics" {
  // Linux/macOS 64-bit ABI: struct rlimit contains two uint64_t values.
  // Signal handlers use pointer-sized UInt64 values on these targets.
  let previous_limits : FixedArray[UInt64] = [0, 0]
  assert_eq(getrlimit(RLIMIT_FSIZE, previous_limits), 0)
  let previous_handler = signal_handler(SIGXFSZ, SIG_IGN)
  assert_not_eq(previous_handler, SIG_ERR)
  defer ignore(signal_handler(SIGXFSZ, previous_handler))
  let path = file_test_path()
  @fs.write_bytes_to_file(path, b"")
  defer @fs.remove_file(path)
  let before = @fs.read_dir("/dev/fd").length()
  let content = Bytes::makei(4096, i => (i % 251).to_byte())
  let file_limit = 1024
  // The first write fills the limit. The next fails with EFBIG.
  assert_eq(
    setrlimit(RLIMIT_FSIZE, [file_limit.to_uint64(), previous_limits[1]]),
    0,
  )
  defer ignore(setrlimit(RLIMIT_FSIZE, previous_limits))
  let IOError(message) = @test.expect_error(() => {
    @fs.write_bytes_to_file(path, content)
  })
  assert_eq(@fs.read_file_to_bytes(path), content[:file_limit].to_owned())
  assert_eq(@fs.read_dir("/dev/fd").length(), before)
  assert_true(message.contains("write"))
  assert_true(message.contains(path))
  assert_false(message.contains("OS error "))
}

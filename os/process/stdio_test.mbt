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

// Exercise stdio in child processes so tests can redirect and close the standard
// streams without changing the test runner's own handles.

///|
test "stdio outputs preserve byte views and empty writes" {
  let (code, out, err) = collect_output(
    child_command(),
    ["stdio_outputs"],
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(out, b"\x00\xff\x80\r\n")
  assert_eq(err, b"\xff\x80\r")
}

///|
test "stdio outputs write complete buffers larger than a pipe" {
  let (code, out, err) = collect_output(
    child_command(),
    ["stdio_large_outputs"],
    extra_env=child_env(),
  )
  let expected = Bytes::from_array(FixedArray::make(1048576, b'x'))
  assert_eq(code, 0)
  assert_eq(out, expected)
  assert_eq(err, expected)
}

///|
test "stdio input preserves all bytes through EOF" {
  let dir = test_dir("stdin-bytes")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let file = dir + "/input"
  for
    bytes in [
      b"",
      b"binary\x00\xff\r\n",
      Bytes::from_array(FixedArray::make(100000, b'\xff')),
    ] {
    @fs.write_file(file, bytes)
    let (code, output) = collect_stdout(
      child_command(),
      ["stdio_stdin"],
      stdin=redirect_from_file(file),
      extra_env=child_env(),
    )
    assert_eq(code, 0)
    assert_eq(output, bytes)
  }
}

///|
test "stdio reports closed handles with the stream context" {
  for mode in ["bad_stdin", "bad_stderr"] {
    let (code, output) = collect_stdout(
      child_command(),
      [mode],
      extra_env=child_env(),
    )
    assert_eq(code, 0)
    assert_eq(output, b"badfd")
  }
  let (code, output) = collect_stderr(
    child_command(),
    ["bad_stdout"],
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(output, b"badfd")
}

///|
test "stdio terminal probes reject redirected files and pipes" {
  let dir = test_dir("stdio-terminals")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let file = dir + "/input"
  @fs.write_file(file, b"")
  let (code, out, err) = collect_output(
    child_command(),
    ["stdio_terminals"],
    stdin=redirect_from_file(file),
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(out, b"false|false|false")
  assert_eq(err, b"")
}

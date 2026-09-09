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
fn capture_error(
  f : () -> Unit raise @os_error.OSError,
) -> @os_error.OSError raise {
  try f() catch {
    err => err
  } noraise {
    _ => fail("expected OSError")
  }
}

///|
test "process errors preserve launch open and validation failures" {
  let dir = test_dir("error-codes")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let missing = dir + "/missing"
  let error = capture_error(() => run(missing, []) |> ignore)
  assert_true(error.is_ENOENT())
  let @os_error.OSError(_, context~) = error
  assert_true(context.contains(missing))
  assert_true(
    capture_error(() => redirect_from_file(missing) |> ignore).is_ENOENT(),
  )
  assert_true(capture_error(() => run("", []) |> ignore).is_EINVAL())
  assert_true(
    capture_error(() => run("bad\u{0}command", []) |> ignore).is_EINVAL(),
  )
  assert_true(capture_error(() => wait_pid(0) |> ignore).is_EINVAL())
  let cmd = child_command()
  let closed = redirect_to_file(dir + "/output")
  closed.close()
  assert_true(
    capture_error(() => {
      run(cmd, ["empty"], stdout=closed, extra_env=child_env()) |> ignore
    }).is_EBADF(),
  )
  let output = redirect_to_file(dir + "/output")
  assert_true(
    capture_error(() => run(missing, [], stdout=output) |> ignore).is_ENOENT(),
  )
  assert_true(
    capture_error(() => {
      run(cmd, ["empty"], stdout=output, extra_env=child_env()) |> ignore
    }).is_EBADF(),
  )
}

///|
test "standard stream helpers preserve bytes and report closed handles" {
  let cmd = child_command()
  let (code, output) = collect_stderr(
    cmd,
    ["root_stderr"],
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(output, b"left\x00right")
  for mode in ["bad_stdin", "bad_stderr"] {
    let (code, output) = collect_stdout(cmd, [mode], extra_env=child_env())
    assert_eq(code, 0)
    assert_eq(output, b"badfd")
  }
  let dir = test_dir("stdin-bytes")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let file = dir + "/input"
  for bytes in [b"", b"binary\x00\xff\r\n"] {
    @fs.write_file(file, bytes)
    let (code, output) = collect_stdout(
      cmd,
      ["root_stdin"],
      stdin=redirect_from_file(file),
      extra_env=child_env(),
    )
    assert_eq(code, 0)
    assert_eq(output, bytes)
  }
}

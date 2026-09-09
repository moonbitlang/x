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
test "explicit exit flushes buffered standard output" {
  let (code, output) = collect_stdout(
    child_command(),
    ["buffered_exit"],
    extra_env=child_env(),
  )
  assert_eq(code, 7)
  let expected = if @os.os_kind() is Windows {
    b"before exit\r\n"
  } else {
    b"before exit\n"
  }
  assert_eq(output, expected)
}

///|
test "command and argument views preserve empty quoted unicode and shell characters" {
  let command = "xx" + child_command()
  let args = [
    "skip", "args", "", "a b", "\"quoted\"", "ends\\", "空 格", "$(echo nope); *",
  ]
  let (code, output) = collect_stdout(
    command[2:],
    args[1:],
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(
    output,
    @encoding/utf8.encode(
      "\u{0}a b\u{0}\"quoted\"\u{0}ends\\\u{0}空 格\u{0}$(echo nope); *\u{0}",
    ),
  )
}

///|
test "collectors retain binary data and nonzero status" {
  let cmd = child_command()
  let (code, out, err) = collect_output(cmd, ["binary"], extra_env=child_env())
  assert_eq(code, 0)
  assert_eq(out, b"\x00\xff\x80\r\n")
  assert_eq(err, b"\xfe\x00")
  let (code, out, err) = collect_output(cmd, ["both"], extra_env=child_env())
  assert_eq((code, out, err), (7, b"out", b"err"))
  let (code, merged) = collect_output_merged(
    cmd,
    ["both"],
    extra_env=child_env(),
  )
  assert_eq((code, merged), (7, b"outerr"))
  assert_eq(run(cmd, ["exit7"], extra_env=child_env()), 7)
}

///|
test "separate pipes drain beyond capacity and handle empty output" {
  let (code, out, err) = collect_output(
    child_command(),
    ["large"],
    extra_env=child_env(),
  )
  assert_eq(code, 0)
  assert_eq(out.length(), 2 * 1024 * 1024)
  assert_eq(err.length(), 2 * 1024 * 1024)
  assert_true(out.to_array().all(b => b == b'x'))
  assert_true(err.to_array().all(b => b == b'y'))
  assert_eq(
    collect_output(child_command(), ["empty"], extra_env=child_env()),
    (0, b"", b""),
  )
}

///|
test "child environment overrides and isolation leave the parent untouched" {
  let saved = @os.getenv("MOON_PROCESS_PARENT")
  defer (match saved {
    Some(value) => @os.setenv("MOON_PROCESS_PARENT", value)
    None => @os.unsetenv("MOON_PROCESS_PARENT")
  })
  @os.setenv("MOON_PROCESS_PARENT", "parent")
  let cmd = child_command()
  let (_, inherited) = collect_stdout(cmd, ["env"], extra_env=child_env())
  assert_eq(inherited, b"parent|missing")
  let overrides = child_env(
    extra=Map([
      ("MOON_PROCESS_PARENT", "child"),
      ("MOON_PROCESS_EXTRA", "空=值"),
    ]),
  )
  let (_, overridden) = collect_stdout(cmd, ["env"], extra_env=overrides)
  assert_eq(overridden, @encoding/utf8.encode("child|空=值"))
  let (_, isolated) = collect_stdout(
    cmd,
    ["env"],
    extra_env=child_env(),
    inherit_env=false,
  )
  assert_eq(isolated, b"missing|missing")
  assert_eq(@os.getenv("MOON_PROCESS_PARENT"), Some("parent"))
}

///|
test "cwd is child-only and redirection opens before child cwd is applied" {
  let dir = test_dir("child cwd 空")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let cwd = @os.cwd()
  let cmd = child_command()
  let (_, output) = collect_stdout(cmd, ["cwd"], cwd=dir, extra_env=child_env())
  assert_eq(
    @fs.realpath(@encoding/utf8.decode_lossy(output[:])),
    @fs.realpath(dir),
  )
  assert_eq(@os.cwd(), cwd)
  expect_error(() => {
    run(cmd, ["empty"], cwd=dir + "/absent", extra_env=child_env()) |> ignore
  })
  assert_eq(@os.cwd(), cwd)
  let file = dir + "/stdin"
  @fs.write_file(file, b"input\x00\xff")
  let input = redirect_from_file(file)
  let (_, output) = collect_stdout(
    cmd,
    ["copy"],
    cwd=dir,
    stdin=input,
    extra_env=child_env(),
  )
  assert_eq(output, b"input\x00\xff")
  expect_error(() => {
    run(cmd, ["empty"], stdin=input, extra_env=child_env()) |> ignore
  })
}

///|
test "single-stream collectors redirect the uncaptured stream" {
  let dir = test_dir("single-stream")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let file = dir + "/other"
  let (code, out) = collect_stdout(
    child_command(),
    ["both"],
    stderr=redirect_to_file(file),
    extra_env=child_env(),
  )
  assert_eq((code, out, @fs.read_file(file)), (7, b"out", b"err"))
  let (code, err) = collect_stderr(
    child_command(),
    ["both"],
    stdout=redirect_to_file(file),
    extra_env=child_env(),
  )
  assert_eq((code, err, @fs.read_file(file)), (7, b"err", b"out"))
}

///|
test "file creation append sharing and one-shot lifetimes" {
  let dir = test_dir("redirection")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let file = dir + "/output"
  let cmd = child_command()
  expect_error(() => redirect_to_file(file, create_mode=OpenExisting) |> ignore)
  expect_error(() => {
    redirect_to_file(file, create_mode=TruncateExisting) |> ignore
  })
  let output = redirect_to_file(file, create_mode=CreateNew)
  assert_true(@fs.exists(file)) // eager, before spawning
  assert_eq(
    run(cmd, ["both"], stdout=output, stderr=output, extra_env=child_env()),
    7,
  )
  assert_eq(@fs.read_file(file), b"outerr")
  output.close()
  expect_error(() => {
    run(cmd, ["empty"], stdout=output, extra_env=child_env()) |> ignore
  })
  expect_error(() => redirect_to_file(file, create_mode=CreateNew) |> ignore)
  let append = redirect_to_file(
    file,
    append=true,
    create_mode=OpenOrCreate,
    shared=true,
  )
  for _ in 0..<2 {
    assert_eq(
      run(cmd, ["both"], stdout=append, stderr=append, extra_env=child_env()),
      7,
    )
  }
  append.close()
  append.close()
  assert_eq(@fs.read_file(file), b"outerrouterrouterr")
  let truncated = redirect_to_file(file, create_mode=TruncateExisting)
  assert_eq(@fs.file_size(file), 0L)
  truncated.close()
  @fs.write_file(file, b"old")
  let existing = redirect_to_file(file, create_mode=OpenExisting)
  assert_eq(run(cmd, ["args", "x"], stdout=existing, extra_env=child_env()), 0)
  assert_eq(@fs.read_file(file), b"x\x00d")
  let truncate_append = redirect_to_file(file, append=true)
  assert_eq(@fs.file_size(file), 0L)
  assert_eq(
    run(
      cmd,
      ["both"],
      stdout=truncate_append,
      stderr=truncate_append,
      extra_env=child_env(),
    ),
    7,
  )
  assert_eq(@fs.read_file(file), b"outerr")
}

///|
test "launch failures close one-shot redirections but preserve shared outputs" {
  let dir = test_dir("failed-launch")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let file = dir + "/output"
  let output = redirect_to_file(file)
  let input = redirect_from_file(file)
  expect_error(() => {
    spawn_orphan(
      dir + "/missing-executable",
      [],
      stdin=input,
      stdout=output,
      stderr=output,
    )
    |> ignore
  })
  expect_error(() => {
    run(child_command(), ["empty"], stdout=output, extra_env=child_env())
    |> ignore
  })
  expect_error(() => {
    run(child_command(), ["empty"], stdin=input, extra_env=child_env())
    |> ignore
  })
  let shared = redirect_to_file(file, shared=true)
  defer shared.close()
  expect_error(() => {
    spawn_orphan(dir + "/missing-executable", [], stdout=shared) |> ignore
  })
  assert_eq(
    run(child_command(), ["empty"], stdout=shared, extra_env=child_env()),
    0,
  )
  expect_error(() => collect_output(dir + "/missing-executable", []) |> ignore)
}

///|
test "PID wait reaps exactly the requested child and rejects repeat waits" {
  let cmd = child_command()
  let first = spawn_orphan(cmd, ["exit7"], extra_env=child_env())
  let second = spawn_orphan(cmd, ["empty"], extra_env=child_env())
  assert_eq(wait_pid(second), 0)
  assert_eq(wait_pid(first), 7)
  expect_error(() => wait_pid(first) |> ignore)
  for pid in [-1, 0, -5] {
    expect_error(() => wait_pid(pid) |> ignore)
  }
  let pid = spawn_orphan(cmd, ["exit7"], extra_env=child_env())
  assert_eq(wait_any(), (pid, 7))
  expect_error(() => wait_any() |> ignore)
  expect_error(() => wait_pid(@os.getpid()) |> ignore)
}

///|
test "invalid command argument environment and path strings raise" {
  let cmd = child_command()
  expect_error(() => run("", []) |> ignore)
  expect_error(() => run(cmd + "\u{0}ignored", []) |> ignore)
  expect_error(() => run(cmd, ["empty\u{0}injected"]) |> ignore)
  expect_error(() => run(cmd, [], extra_env=Map([("", "value")])) |> ignore)
  expect_error(() => run(cmd, [], extra_env=Map([("a=b", "value")])) |> ignore)
  expect_error(() => {
    run(cmd, [], extra_env=Map([("a", "value\u{0}")])) |> ignore
  })
  expect_error(() => run(cmd, [], cwd="\u{0}") |> ignore)
  expect_error(() => redirect_to_file("bad\u{0}path") |> ignore)
  assert_eq(which("\u{0}"), None)
}

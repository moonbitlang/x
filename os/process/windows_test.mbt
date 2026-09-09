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
#cfg(platform="windows")
extern "c" fn current_process() -> Int64 = "GetCurrentProcess"

///|
#cfg(platform="windows")
#borrow(count)
extern "c" fn process_handle_count(
  process : Int64,
  count : FixedArray[Int],
) -> Int = "GetProcessHandleCount"

///|
#cfg(platform="windows")
test "Windows which respects PATH order before executable extensions" {
  let dir = test_dir("which order 空")
  @fs.mkdir(dir + "/first", recursive=true)
  @fs.mkdir(dir + "/second")
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.write_file(dir + "/first/tool.cmd", b"@exit /b 0\r\n")
  @fs.write_file(dir + "/second/tool.exe", b"fixture")
  @fs.write_file(dir + "/second/tool.custom", b"fixture")
  @fs.mkdir(dir + "/first/directory.exe")
  let saved_path = @os.getenv("PATH")
  let saved_ext = @os.getenv("PATHEXT")
  defer {
    match saved_path {
      Some(value) => @os.setenv("PATH", value)
      None => @os.unsetenv("PATH")
    }
    match saved_ext {
      Some(value) => @os.setenv("PATHEXT", value)
      None => @os.unsetenv("PATHEXT")
    }
  }
  @os.setenv("PATH", "\"" + dir + "/first\";" + dir + "/second")
  @os.setenv("PATHEXT", ".EXE;.CMD")
  assert_eq(
    @fs.realpath(which("tool").unwrap()),
    @fs.realpath(dir + "/first/tool.cmd"),
  )
  assert_eq(
    @fs.realpath(which("tool.exe").unwrap()),
    @fs.realpath(dir + "/second/tool.exe"),
  )
  assert_eq(which("directory"), None)
  @os.setenv("PATHEXT", ".CUSTOM;.EXE")
  assert_eq(
    @fs.realpath(which("tool").unwrap()),
    @fs.realpath(dir + "/second/tool.custom"),
  )
}

///|
#cfg(platform="windows")
test "Windows preserves 259 and high-bit exit codes after waiting" {
  let cmd = child_command()
  assert_eq(
    run(cmd, ["exit259"], extra_env=child_env(), no_console_window=true),
    259,
  )
  assert_eq(run(cmd, ["exit_high"], extra_env=child_env()), -2147483647)
  assert_eq(
    collect_output(cmd, ["exit_high"], extra_env=child_env()),
    (-2147483647, b"", b""),
  )
  let pid = spawn_orphan(cmd, ["exit_high"], extra_env=child_env())
  assert_eq(wait_any(), (pid, -2147483647))
}

///|
#cfg(platform="windows")
test "Windows environment overrides are case insensitive" {
  let saved = @os.getenv("MOON_PROCESS_PARENT")
  defer (match saved {
    Some(value) => @os.setenv("MOON_PROCESS_PARENT", value)
    None => @os.unsetenv("MOON_PROCESS_PARENT")
  })
  @os.setenv("MOON_PROCESS_PARENT", "parent")
  let (_, output) = collect_stdout(
    child_command(),
    ["env"],
    extra_env=child_env(extra=Map([("moon_process_parent", "child")])),
  )
  assert_eq(output, b"child|missing")
  assert_eq(@os.getenv("MOON_PROCESS_PARENT"), Some("parent"))
}

///|
#cfg(platform="windows")
test "Windows collection and failed launches do not leak handles" {
  let dir = test_dir("handle-leaks")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let count = FixedArray::make(1, 0)
  // Warm up CRT/thread initialization before comparing handle counts.
  collect_output(child_command(), ["binary"], extra_env=child_env()) |> ignore
  assert_true(process_handle_count(current_process(), count) != 0)
  let before = count[0]
  for _ in 0..<20 {
    expect_error(() => collect_output(dir + "/missing", []) |> ignore)
    expect_error(() => {
      run(
        child_command(),
        [],
        cwd=dir + "/missing",
        stdout=redirect_to_file(dir + "/out"),
      )
      |> ignore
    })
    collect_output(child_command(), ["binary"], extra_env=child_env()) |> ignore
  }
  assert_true(process_handle_count(current_process(), count) != 0)
  assert_eq(count[0], before)
}

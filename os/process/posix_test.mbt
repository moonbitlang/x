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
#cfg(not(platform="windows"))
test "signals are statuses rather than operation errors" {
  let cmd = child_command()
  assert_eq(run(cmd, ["signal"], extra_env=child_env()), -15)
  let (code, out, err) = collect_output(cmd, ["signal"], extra_env=child_env())
  assert_eq((code, out, err), (-15, b"", b""))
  let pid = spawn_orphan(cmd, ["signal"], extra_env=child_env())
  assert_eq(wait_any(), (pid, -15))
}

///|
#cfg(not(platform="windows"))
test "redirection applies permissions and relative child executable lookup" {
  let dir = test_dir("permissions")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let path = dir + "/private"
  let output = redirect_to_file(path, permission=0o600)
  output.close()
  let stat_args = if @os.os_kind() is @os.Macos {
    ["-f", "%Lp", path]
  } else {
    ["-c", "%a", path]
  }
  let (_, permissions) = collect_stdout("stat", stat_args[:])
  assert_eq(permissions, b"600\n")
  let child = dir + "/child"
  @fs.hardlink(child_command(), child)
  let (_, out) = collect_stdout(
    "./child",
    ["args", "ok"],
    cwd=dir,
    extra_env=child_env(),
  )
  assert_eq(out, b"ok\x00")
}

///|
#cfg(not(platform="windows"))
test "capture and failed launch paths do not leak file descriptors" {
  let dir = test_dir("fd-leaks")
  @fs.mkdir(dir, recursive=true)
  defer (@fs.remove_all(dir) catch { _ => () })
  let fd_dir = if @os.os_kind() is @os.Macos {
    "/dev/fd"
  } else {
    "/proc/self/fd"
  }
  let before = @fs.readdir(fd_dir).length()
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
  assert_eq(@fs.readdir(fd_dir).length(), before)
}

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
fn temp_dir() -> String {
  match @env.get_env_var("TMPDIR") {
    Some(path) if path != "" => return path
    _ => ()
  }
  match @env.get_env_var("TEMP") {
    Some(path) if path != "" => return path
    _ => ()
  }
  match @env.get_env_var("TMP") {
    Some(path) if path != "" => return path
    _ => ()
  }
  "/tmp"
}

///|
fn test_dir(name : String) -> String {
  temp_dir() + "/moonbit-unix-test-" + @os.getpid().to_string() + "-" + name
}

///|
#cfg(not(platform="windows"))
test "argv execution bypasses the shell" {
  let (code, output) = collect_output_merged("printf", ["%s", "a b c"])
  inspect(code, content="0")
  assert_eq(output, b"a b c")
}

///|
#cfg(not(platform="windows"))
test "redirected spawn and wait_any preserve the child result" {
  let dir = test_dir("spawn-to")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let output = dir + "/child.out"
  let redirect = redirect_to_file(output)
  let expected_pid = spawn_orphan(
    "sh",
    ["-c", "printf child"],
    stdout=redirect,
    stderr=redirect,
  )
  let (actual_pid, code) = wait_any()
  inspect(actual_pid == expected_pid, content="true")
  inspect(code, content="0")
  assert_true(@fs.read_file(output) == b"child")
}

///|
#cfg(not(platform="windows"))
test "spawn_orphan and wait_any wait for completion" {
  let dir = test_dir("spawn")
  @fs.remove_all(dir)
  defer (@fs.remove_all(dir) catch { _ => () })
  @fs.mkdir(dir, recursive=true)
  let output = dir + "/child.out"
  let expected_pid = spawn_orphan("sh", ["-c", "printf child > " + output])
  let (actual_pid, code) = wait_any()
  inspect(actual_pid == expected_pid, content="true")
  inspect(code, content="0")
  assert_true(@fs.read_file(output) == b"child")
}

///|
#cfg(platform="windows")
test "Windows process probes" {
  assert_true(which("cmd") is Some(_))
}

///|
#cfg(not(platform="windows"))
test "POSIX process probes" {
  assert_true(which("sh") is Some(_))
}

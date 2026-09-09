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
  match @os.getenv("TMPDIR") {
    Some(path) if path != "" => return path
    _ => ()
  }
  match @os.getenv("TEMP") {
    Some(path) if path != "" => return path
    _ => ()
  }
  match @os.getenv("TMP") {
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
test "argv execution bypasses the shell" {
  if @os.os_kind() is @os.Windows {
    return
  }
  let (code, output) = collect_output_merged("printf", ["%s", "a b c"])
  inspect(code, content="0")
  assert_eq(output, b"a b c")
}

///|
test "redirected spawn and wait_any preserve the child result" {
  if @os.os_kind() is @os.Windows {
    return
  }
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
test "spawn_orphan and wait_any wait for completion" {
  if @os.os_kind() is @os.Windows {
    return
  }
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
test "process probes" {
  if @os.os_kind() is @os.Windows {
    assert_true(which("cmd") is Some(_))
  } else {
    assert_true(which("sh") is Some(_))
  }
}

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
#borrow(argv, env, cwd, streams, result)
extern "c" fn native_spawn(
  argv : Bytes,
  argc : Int,
  env : Bytes,
  envc : Int,
  inherit_env : Int,
  cwd : Bytes,
  has_cwd : Int,
  streams : FixedArray[Int64],
  no_console_window : Int,
  result : FixedArray[Int],
) -> Int = "moonbit_community_unix_process_spawn"

///|
#borrow(result)
extern "c" fn native_wait(pid : Int, result : FixedArray[Int]) -> Int = "moonbit_community_unix_process_wait"

///|
#borrow(result)
extern "c" fn native_collect(
  stdout : Int64,
  stderr : Int64,
  result : FixedArray[Int],
) -> Bytes = "moonbit_community_unix_process_collect"

///|
#borrow(tool)
extern "c" fn native_which(tool : Bytes) -> Bytes = "moonbit_community_unix_which"

///|
fn cstr(s : StringView) -> Bytes {
  @encoding/utf8.encode(s)
}

///|
fn fail(
  operation : String,
  detail : StringView,
  code : Int,
) -> Unit raise @os_error.OSError {
  raise OSError(code, context=operation + ": " + detail.to_owned())
}

///|
fn validate_string(s : StringView) -> Unit raise @os_error.OSError {
  @ffi.validate_string(s, "process")
}

///|
fn argv_blob(
  cmd : StringView,
  args : ArrayView[String],
) -> Bytes raise @os_error.OSError {
  if cmd.is_empty() {
    @ffi.invalid_argument("spawn_orphan: command must not be empty")
  }
  validate_string(cmd)
  let builder = StringBuilder()
  builder.write_stringview(cmd)
  builder.write_char('\u{0}')
  for arg in args {
    validate_string(arg)
    builder.write_string(arg)
    builder.write_char('\u{0}')
  }
  cstr(builder.to_string())
}

///|
fn env_blob(env : Map[String, String]) -> Bytes raise @os_error.OSError {
  let builder = StringBuilder()
  for key, value in env {
    validate_string(key)
    validate_string(value)
    if key.is_empty() || key.contains("=") {
      @ffi.invalid_argument(
        "spawn_orphan: environment names must be nonempty and must not contain '='",
      )
    }
    builder.write_string(key)
    builder.write_char('=')
    builder.write_string(value)
    builder.write_char('\u{0}')
  }
  cstr(builder.to_string())
}

///|
/// Start a program directly and return its PID, without waiting. args excludes
/// the executable. Pair with wait_pid or wait_any to reap the child.
/// Omitted streams, environment and cwd are inherited. Overrides affect only the
/// child; executable lookup uses the parent's search path, as in async/process.
/// On POSIX, the child starts with an empty signal mask and default signal
/// dispositions, so it does not inherit the parent's async runtime signal state.
/// On Windows, no_console_window suppresses creation of a console window.
/// One-shot redirections are closed after the attempt, even when spawning fails.
pub fn spawn_orphan(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  stdout? : ProcessOutput,
  stderr? : ProcessOutput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> Int raise @os_error.OSError {
  defer {
    if stdin is Some(input) {
      input.close()
    }
    if stdout is Some(output) {
      output.after_spawn()
    }
    if stderr is Some(output) {
      output.after_spawn()
    }
  }
  let argv = argv_blob(cmd, args)
  let env = env_blob(extra_env)
  let directory = match cwd {
    Some(path) => {
      validate_string(path)
      cstr(path)
    }
    None => b""
  }
  let streams = FixedArray::make(3, -1L)
  if stdin is Some(input) {
    streams[0] = input.fd()
  }
  if stdout is Some(output) {
    streams[1] = output.fd()
  }
  if stderr is Some(output) {
    streams[2] = output.fd()
  }
  let result = FixedArray::make(1, 0)
  let code = native_spawn(
    argv,
    args.length() + 1,
    env,
    extra_env.length(),
    if inherit_env {
      1
    } else {
      0
    },
    directory,
    if cwd is Some(_) {
      1
    } else {
      0
    },
    streams,
    if no_console_window {
      1
    } else {
      0
    },
    result,
  )
  if code != 0 {
    fail("spawn_orphan", cmd, code)
  }
  result[0]
}

///|
/// Run a program directly, synchronously, with the same options as spawn_orphan.
/// A nonzero exit is a result, not an error. On POSIX a signal produces the
/// negative signal number; on Windows all 32 bits of the exit code are retained.
pub fn run(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  stdout? : ProcessOutput,
  stderr? : ProcessOutput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> Int raise @os_error.OSError {
  let pid = spawn_orphan(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    no_console_window~,
  )
  wait_pid(pid)
}

///|
/// Wait for a specific child. Waiting twice or passing a non-child PID raises.
/// Only positive PIDs are accepted: this never waits on a process group.
pub fn wait_pid(pid : Int) -> Int raise @os_error.OSError {
  if pid <= 0 {
    @ffi.invalid_argument("wait_pid: expected a positive child PID")
  }
  let result = FixedArray::make(2, 0)
  let code = native_wait(pid, result)
  if code != 0 {
    fail("wait_pid", pid.to_string(), code)
  }
  result[1]
}

///|
/// Synchronous extension for process pools: reap any child and return its PID
/// and status. POSIX waits for any child; Windows waits for a child started by
/// this package. Each child must have only one waiter.
pub fn wait_any() -> (Int, Int) raise @os_error.OSError {
  let result = FixedArray::make(2, 0)
  let code = native_wait(-1, result)
  if code != 0 {
    fail("wait_any", "waiting for a child", code)
  }
  (result[0], result[1])
}

///|
/// Collect stdout and stderr separately as bytes. Both pipes are drained while
/// the child runs, so neither stream is limited to the OS pipe-buffer capacity.
pub fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> (Int, Bytes, Bytes) raise @os_error.OSError {
  collect(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout=None,
    stderr=None,
    cwd~,
    no_console_window~,
    mode=0,
  )
}

///|
/// Collect stdout and stderr through one pipe, retaining their merged order.
/// Array[String] intentionally matches async/process 0.21.2's merged collector.
pub fn collect_output_merged(
  cmd : StringView,
  args : Array[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> (Int, Bytes) raise @os_error.OSError {
  let (code, output, _) = collect(
    cmd,
    args[:],
    extra_env~,
    inherit_env~,
    stdin~,
    stdout=None,
    stderr=None,
    cwd~,
    no_console_window~,
    mode=1,
  )
  (code, output)
}

///|
/// Collect stdout as bytes, inheriting stderr unless explicitly redirected.
pub fn collect_stdout(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  stderr? : ProcessOutput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> (Int, Bytes) raise @os_error.OSError {
  let (code, output, _) = collect(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout=None,
    stderr~,
    cwd~,
    no_console_window~,
    mode=2,
  )
  (code, output)
}

///|
/// Collect stderr as bytes, inheriting stdout unless explicitly redirected.
pub fn collect_stderr(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
  stdin? : ProcessInput,
  stdout? : ProcessOutput,
  cwd? : StringView,
  no_console_window? : Bool = false,
) -> (Int, Bytes) raise @os_error.OSError {
  let (code, _, output) = collect(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin~,
    stdout~,
    stderr=None,
    cwd~,
    no_console_window~,
    mode=3,
  )
  (code, output)
}

///|
fn collect(
  cmd : StringView,
  args : ArrayView[String],
  extra_env~ : Map[String, String],
  inherit_env~ : Bool,
  stdin~ : ProcessInput?,
  stdout~ : ProcessOutput?,
  stderr~ : ProcessOutput?,
  cwd~ : StringView?,
  no_console_window~ : Bool,
  mode~ : Int,
) -> (Int, Bytes, Bytes) raise @os_error.OSError {
  // Cover setup failures before spawn_orphan has taken responsibility too.
  defer {
    if stdin is Some(input) {
      input.close()
    }
    if stdout is Some(output) {
      output.after_spawn()
    }
    if stderr is Some(output) {
      output.after_spawn()
    }
  }
  let (read_first, write_first) = capture_pipe()
  defer {
    read_first.close()
    write_first.close()
  }
  let second = if mode == 0 { Some(capture_pipe()) } else { None }
  defer (if second is Some((input, output)) {
    input.close()
    output.close()
  })
  let child_stdout = if mode == 3 { stdout } else { Some(write_first) }
  let child_stderr = match second {
    Some((_, output)) => Some(output)
    None => if mode == 1 || mode == 3 { Some(write_first) } else { stderr }
  }
  let pid = spawn_orphan(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?=child_stdout,
    stderr?=child_stderr,
    cwd?,
    no_console_window~,
  )
  let result = FixedArray::make(2, 0)
  // Transfer reader ownership to native_collect. It closes each stream at EOF
  // or on error, including errors while the other stream is still being read.
  let first_fd = read_first.handle
  read_first.handle = -1L
  let second_fd = match second {
    Some((input, _)) => {
      let fd = input.handle
      input.handle = -1L
      fd
    }
    None => -1L
  }
  let bytes = native_collect(first_fd, second_fd, result)
  // Always reap the child, even when collection failed.
  if result[1] != 0 {
    let _ = wait_pid(pid) catch { _ => 0 }
    fail("collect_output", cmd, result[1])
  }
  let code = wait_pid(pid)
  if mode == 0 {
    (code, bytes[:result[0]].to_owned(), bytes[result[0]:].to_owned())
  } else if mode == 3 {
    (code, b"", bytes)
  } else {
    (code, bytes, b"")
  }
}

///|
/// Synchronous extension: locate an executable using the host's search path.
pub fn which(tool : StringView) -> String? {
  for c in tool.code_units() {
    if c == 0 {
      return None
    }
  }
  if tool.is_empty() {
    return None
  }
  let path = @encoding/utf8.decode_lossy(native_which(cstr(tool))[:])
  if path == "" {
    None
  } else {
    Some(path)
  }
}

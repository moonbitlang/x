# moonbitlang/x/os/process

Synchronous native process execution. Names, labels and defaults follow the
workspace's `moonbitlang/async@0.21.2`. This package has no async dependency:
operations block, raise `@os_error.OSError` on operation failures, and collect
`Bytes` instead of async's `&@io.Data`. Encoding and shell policy belong to callers.

See [the generated interface](pkg.generated.mbti) for complete signatures
and [the error model](../os_error/README.md) for portable error handling.
OS error codes are captured before cleanup; a missing command or redirection
file can be recognized with `is_ENOENT()`. Invalid arguments use `is_EINVAL()`;
reusing a closed redirection uses `is_EBADF()`.

## Async-aligned surface

In this table, `cmd : StringView` and `args : ArrayView[String]`. Arguments do not
include the executable. Optional arguments are listed separately below.
`collect_output_merged` intentionally takes `Array[String]`, matching async 0.21.2.
All synchronous functions in this table raise `@os_error.OSError`.

| Synchronous signature | Async 0.21.2 signature |
| --- | --- |
| `fn run(cmd, args) -> Int` | `async fn run(cmd, args) -> Int` |
| `fn spawn_orphan(cmd, args) -> Int` | `async fn spawn_orphan(cmd, args) -> Int` |
| `fn wait_pid(Int) -> Int` | `async fn wait_pid(Int) -> Int` |
| `fn collect_output(cmd, args) -> (Int, Bytes, Bytes)` | `async fn collect_output(cmd, args) -> (Int, &@io.Data, &@io.Data)` |
| `fn collect_output_merged(cmd, args) -> (Int, Bytes)` | `async fn collect_output_merged(cmd, args) -> (Int, &@io.Data)` |
| `fn collect_stdout(cmd, args) -> (Int, Bytes)` | `async fn collect_stdout(cmd, args) -> (Int, &@io.Data)` |
| `fn collect_stderr(cmd, args) -> (Int, Bytes)` | `async fn collect_stderr(cmd, args) -> (Int, &@io.Data)` |

| Optional argument | Synchronous type | Async type | Default |
| --- | --- | --- | --- |
| `extra_env?` | `Map[String, String]` | Same | Empty map |
| `inherit_env?` | `Bool` | Same | `true` |
| `cwd?` | `StringView` | Same | Parent's cwd |
| `no_console_window?` | `Bool` | Same | `false` |
| `stdin?` | `ProcessInput` | `&ProcessInput` | Inherit |
| `stdout?`, `stderr?` | `ProcessOutput` | `&ProcessOutput` | Inherit |

`run` and `spawn_orphan` accept all these options. All collectors accept the
environment, cwd, console and stdin options. `collect_stdout` additionally accepts
`stderr?`; `collect_stderr` accepts `stdout?`. The two-stream collectors own both
output streams and accept neither output override. Async `run` also accepts
`cancel_handler?`, which has no synchronous counterpart here.

Environment overrides never mutate the parent. Names are case-sensitive on POSIX
and case-insensitive on Windows. `inherit_env=false` starts with an empty child
environment before applying overrides. Executable lookup uses the parent's search
path; changing the child's PATH does not change that search. A relative executable
path with a slash is resolved in the child cwd on POSIX; Windows uses CreateProcess
lookup rules. Use an absolute executable path for portable cwd behavior.

`run` executes a program directly, not a shell command. Windows uses MSVCRT-style
argument quoting; programs with their own command-line grammar (notably `cmd.exe`)
may require their own adapter. `no_console_window` maps to `CREATE_NO_WINDOW` on
Windows and is ignored on POSIX. NUL in commands, arguments, environment or paths,
and empty or `=`-containing environment names, raise before launching a child.

A nonzero exit code is a result, not an operation failure. POSIX signal termination
returns the negative signal number, as in async (for example, SIGTERM returns
`-15`). Windows retains all 32 bits of the exit code, including `259` and codes
whose `Int` representation is negative. Errors are independent of these statuses.

Collectors drain both pipes while the child runs, without temporary files.
Separate capture returns `(status, stdout, stderr)` and does not preserve
cross-stream ordering; merged capture routes both streams through one pipe.
Output must fit in memory and in a MoonBit `Bytes` value.

## File redirection and ownership

| Synchronous signature | Async 0.21.2 signature |
| --- | --- |
| `fn redirect_from_file(String) -> ProcessInput` | `async fn redirect_from_file(String) -> &ProcessInput` |
| `fn redirect_to_file(String, append?, create_mode?, permission?, shared?) -> ProcessOutput` | `async fn redirect_to_file(String, append?, create_mode?, permission?, shared?) -> &ProcessOutput` |

Both synchronous factories raise `@os_error.OSError`. Output defaults match async:
`append=false`, `create_mode=@fs.CreateOrTruncate`, `permission=0o644`, and
`shared=false`. Creation modes come from `moonbitlang/x/os/fs`:
`OpenExisting`, `TruncateExisting`, `OpenOrCreate`, `CreateOrTruncate`, `CreateNew`.
Append is independent of creation: use `OpenOrCreate` to preserve existing data;
the default still truncates with `append=true`. Permission is masked by POSIX
umask and ignored on Windows.

Files open eagerly, relative to the parent's current directory, before any child
cwd change. Input and default output handles are one-shot: passing one to a launch
attempt closes the parent's handle on success or failure. One output may serve
both stdout and stderr of that child. Reusing a consumed or closed handle raises.

With `shared=true`, an output can serve multiple children and retains its file
position. Close it explicitly after the final spawn; children keep their own
handles, so there is no need to wait first. Close unused inputs/outputs too.
Both `ProcessInput::close()` and `ProcessOutput::close()` are idempotent and do not
raise. Resource cleanup is explicit; dropping an unused handle is not a substitute
for closing it. These handles are not intended for concurrent use across threads.

## PID lifecycle and migration

`spawn_orphan` is unstructured: it returns a PID and does not automatically cancel
the child. Pair it with `wait_pid` or `wait_any`. A child has one waiter and is
reaped once; repeat waits raise. `wait_pid` accepts only positive PIDs. There is
no TaskGroup-style `spawn`, `Process` handle, cancellation API, or public streaming
pipe API in this first pass.

Two synchronous extensions remain:

- `wait_any() -> (Int, Int) raise @os_error.OSError` returns a reaped PID and status.
  POSIX waits for any child; Windows waits for children launched by this package.
  Windows retains at most 1024 outstanding child handles; reap children regularly.
- `which(StringView) -> String?` searches the host executable path.

| Old synchronous API | Replacement |
| --- | --- |
| `exec(argv)` | `run(argv[0], argv[1:])` |
| `spawn_argv(argv)` | `spawn_orphan(argv[0], argv[1:])` |
| `capture_argv`, `capture_argv_bytes` | `collect_output_merged` |
| `capture_argv_split` | `collect_output` |
| `capture_argv_stdin` | `collect_output` with `stdin=redirect_from_file(path)` |
| `spawn_argv_to` | `spawn_orphan` with the same file output for stdout and stderr |
| Shell `run(String)` / `spawn(String)` | Explicit platform-shell invocation |

The compiler's `src/util/os` facade retains its existing names, string decoding,
shell-command handling (including cmd's raw command syntax), failure fallbacks
and shell-style POSIX signal statuses (`128 + signal`). Scheduler callers do not
need to change. On Windows, the facade honors a fully qualified `COMSPEC`; when
it is absent, empty or relative, it uses `cmd.exe` from `GetSystemDirectoryW`.
The shell executable is passed explicitly to `CreateProcessW`, never searched
in the project's cwd or PATH. An unusable absolute override fails the launch.

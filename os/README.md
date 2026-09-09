# moonbitlang/x/os

Synchronous native operating-system operations for MoonBit.

The API is divided into four public packages:

- `moonbitlang/x/os` provides environment and process-global
  state, standard-stream helpers, clocks, and host information.
- [`moonbitlang/x/os/os_error`](os_error/README.md) provides native error
  codes, operation context, and portable error classification matching async.
- [`moonbitlang/x/os/fs`](fs/README.md) provides byte-oriented file I/O,
  filesystem metadata, and mutation with async-aligned names and options.
- [`moonbitlang/x/os/process`](process/README.md) provides direct process
  spawning, byte-oriented output capture, file redirection, PID waiting, and
  executable lookup with async-aligned names and options.

Operations are synchronous and may block the calling thread. Failures that are
part of an operation's contract raise `@os_error.OSError`. Filesystem probes return
`Bool` for missing paths (and denied access for `can_*`) and raise on unexpected
errors; `kind` raises for missing paths instead of returning a `Missing` variant.

These packages support POSIX and Windows native targets. Windows adapts the
Unix-shaped API to Win32 semantics. Wasm and JavaScript targets are unsupported.

The portable API covers process execution and capture, path and file operations,
directory listing, links, timestamps, environment variables, and host process
information. Shared
POSIX/Win32 stubs live under `internal/ffi`; the public packages expose MoonBit
APIs without depending on the compiler or the async runtime. File descriptors,
sockets, signals, users/groups, and terminal control are outside the initial scope.

`read_stdin_bytes`, `read_stdin`, and `write_stderr` raise on I/O failures.
The byte reader preserves binary input; the text reader decodes UTF-8 lossily.
`write_stderr` writes the complete UTF-8 text, including embedded NUL. `now_ns`
is a monotonic clock with an arbitrary origin, intended for elapsed-time
measurements.

Compiler-specific cache buffers (`stat_into`), batch materialization
(`hardlink_many`), and typed directory classification (`list_dir`/`DirEntry`)
live in moon's `src/util/os` package and are outside this package family's public API.

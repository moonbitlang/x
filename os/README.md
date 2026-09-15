# moonbitlang/x/os

Synchronous native operating-system operations for MoonBit.

The API is divided into five public packages:

- `moonbitlang/x/os` provides current-directory operations, clocks, and host
  process information.
- [`moonbitlang/x/os/os_error`](os_error/README.md) provides native error
  codes, operation context, and portable error classification matching async.
- [`moonbitlang/x/os/fs`](fs/README.md) provides byte-oriented file I/O,
  filesystem metadata, and mutation with async-aligned names and options.
- [`moonbitlang/x/os/stdio`](stdio/README.md) provides synchronous byte I/O
  and terminal detection for standard input, output, and error streams.
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
directory listing, links, timestamps, and host process information. Command-line
arguments and process environment variables are provided by `moonbitlang/core/env`.
Process termination is provided by `moonbitlang/x/sys.exit`.
Shared POSIX/Win32 stubs live under `internal/ffi`; the public packages expose MoonBit
APIs without depending on the compiler or the async runtime. File descriptors,
sockets, signals, users/groups, and terminal control are outside the initial scope.

`stdio.stdin.read_all()`, `stdio.stdout.write(bytes)`, and
`stdio.stderr.write(bytes)` preserve binary data and report returned I/O failures
as errors. POSIX writes retain the process's SIGPIPE disposition. Callers choose
text encoding, decoding, and newline handling.

`monotonic_now_ns` reads a monotonic clock with an arbitrary origin, intended for
elapsed-time measurements, and raises if the clock is unavailable. Nanosecond units
do not imply nanosecond resolution. `available_parallelism` estimates capacity
from online logical CPUs, falling back to 1. It does not account for process
affinity or CPU quotas.

Compiler-specific platform classification, cache buffers (`stat_into`), batch
materialization (`hardlink_many`), and typed directory classification (`list_dir`/`DirEntry`)
live in moon's `src/util/os` package and are outside this package family's public API.

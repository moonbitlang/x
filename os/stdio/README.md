# moonbitlang/x/os/stdio

Synchronous access to the current process's standard streams on POSIX and Windows.

Like [async/stdio](https://github.com/moonbitlang/async/tree/main/src/stdio), this
package exposes `stdin: Input`, `stdout: Output`, and `stderr: Output`.
These values refer to the process's current standard handles without owning them.

| API | Behavior |
| --- | --- |
| `stdin.read_all()` | Read bytes until EOF; raise `OSError` on failure. |
| `stdout.write(bytes)`, `stderr.write(bytes)` | Write the complete `BytesView`; raise `OSError` for returned I/O failures. |
| `stdin.is_terminal()`, `stdout.is_terminal()`, `stderr.is_terminal()` | Return whether the stream is attached to a terminal; return false if it cannot be queried. |

Reads and writes may block. Bytes, including NUL and invalid UTF-8, pass through
unchanged. Empty writes do nothing. Writes go directly to the underlying stream;
a failed write may already have written a prefix. A failed read raises instead
of returning partial input.

POSIX writes retain the process's SIGPIPE disposition. A broken pipe can terminate
the process unless the caller handles or ignores SIGPIPE.

Text encoding, decoding, formatting, and newline handling belong to callers.
For example, with this package imported as `@stdio`:

```mbt
fn copy_stdin() -> Unit raise {
  @stdio.stdout.write(@stdio.stdin.read_all())
}
```

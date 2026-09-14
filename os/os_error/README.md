# moonbitlang/x/os/os_error

Native operating-system errors for the synchronous unix module. The public
constructor follows `moonbitlang/async/os_error`: `OSError(code, context~)`.
This package has no dependency on async; its error type is a distinct type.

`code` is the captured POSIX `errno` or Windows `GetLastError` value. `context`
identifies the operation and, where relevant, the path or command. Cleanup does
not replace the original failure. `Show` and `Debug` include the system's error
description; `ToJson` preserves the code and context for structured diagnostics.
Messages can vary by OS and locale, so use predicates instead of parsing text:

| Predicate | Meaning |
| --- | --- |
| `is_ENOENT()` | Missing file or directory; recognizes both Windows missing-file and missing-path codes |
| `is_EEXIST()` | Destination already exists; recognizes both Windows file-exists codes |
| `is_EACCES()` | Permission denied |
| `is_ENOTDIR()` | A path component is not a directory |
| `is_EINTR()` | Interrupted operation; always false on Windows, matching async |
| `is_EINVAL()` | Invalid argument, including embedded NUL in a path or process argument |
| `is_EBADF()` | Closed or invalid file descriptor/handle |

The first five predicates have the same names and native-code mappings as
async's counterparts. `is_EINVAL` and `is_EBADF` also cover validation and
redirection lifetimes in the synchronous API. Other errors retain their native
codes even when there is no convenience predicate.

`check_errno(context)` follows async's synchronous FFI pattern: it reads the
current thread's `errno` (POSIX) or `GetLastError()` (Windows), and raises an
`OSError` if the code is nonzero. Call it immediately after a native function
reports failure. Construct the context before that native call, and preserve the
original error across any cleanup in the C wrapper. Keep borrowed arguments alive
until after the check (`defer ignore(bytes)`) so reference-count cleanup cannot
overwrite the error. Do not call it after success: native functions may leave an
earlier error in place.

The scalar wrappers for file size, kind, access checks, and redirection handles
use a `-1` failure result followed by `check_errno`. Buffer returns retain an
explicit error output because empty bytes can be a successful result.

```moonbit
try @fs.read_file(path) catch {
  err => {
    if err.is_ENOENT() {
      b"" // Caller-specific policy for a missing file.
    } else {
      raise err
    }
  }
}
```

Nonzero child exit statuses, including negative POSIX signal numbers, are
successful process results rather than `OSError` values.

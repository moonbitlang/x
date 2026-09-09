# moonbitlang/x/os/fs

Synchronous native filesystem operations. Names, labels, enum variants, and
defaults follow the workspace's `moonbitlang/async@0.21.2` filesystem API.
The package does not depend on async: operations block, raise `@os_error.OSError`,
and use `Bytes` instead of async's `&@io.Data`. String encoding belongs to callers.

See [the generated interface](pkg.generated.mbti) for the complete public API
and [the error model](../os_error/README.md) for portable error handling.
`hardlink` and `readlink` are extensions: async 0.21.2 has no counterparts for them.

## Async-aligned surface

All paths accept `StringView`; embedded NUL raises `OSError` with `is_EINVAL()`
before touching the filesystem. Every synchronous function below raises
`@os_error.OSError`; async functions use their usual async error effect. Optional
arguments and their defaults are listed separately to keep the comparison short.

| Synchronous signature | Async 0.21.2 signature | Shared optional arguments |
| --- | --- | --- |
| `fn read_file(StringView) -> Bytes` | `async fn read_file(StringView) -> &@io.Data` | `sync_timestamp? : Bool = false` |
| `fn write_file(StringView, Bytes) -> Unit` | `async fn write_file(StringView, &@io.Data) -> Unit` | See write options below |
| `fn exists(StringView) -> Bool` | `async fn exists(StringView) -> Bool` | — |
| `fn can_read(StringView) -> Bool` | `async fn can_read(StringView) -> Bool` | — |
| `fn can_write(StringView) -> Bool` | `async fn can_write(StringView) -> Bool` | — |
| `fn can_execute(StringView) -> Bool` | `async fn can_execute(StringView) -> Bool` | — |
| `fn kind(StringView) -> FileKind` | `async fn kind(StringView) -> FileKind` | `follow_symlink? : Bool = true` |
| `fn mtime(StringView) -> (Int64, Int)` | `async fn mtime(StringView) -> (Int64, Int)` | `follow_symlink? : Bool = true` |
| `fn file_size(StringView) -> Int64` | `async fn file_size(StringView) -> Int64` | — |
| `fn mkdir(StringView) -> Unit` | `async fn mkdir(StringView) -> Unit` | `permission? : Int = 0o755`, `recursive? : Bool = false` |
| `fn remove(StringView) -> Unit` | `async fn remove(StringView) -> Unit` | — |
| `fn rmdir(StringView) -> Unit` | `async fn rmdir(StringView) -> Unit` | `recursive? : Bool = false` |
| `fn readdir(StringView) -> Array[String]` | `async fn readdir(StringView) -> Array[String]` | `include_hidden? : Bool = true`, `include_special? : Bool = false`, `sort? : Bool = false` |
| `fn realpath(StringView) -> String` | `async fn realpath(StringView) -> String` | — |

The shared `write_file` options are:

```moonbit
create_mode? : CreateMode = CreateOrTruncate
permission? : Int = 0o644
sync? : SyncMode = Data
append? : Bool = false
```

| `CreateMode` | Missing file | Existing file |
| --- | --- | --- |
| `OpenExisting` | Error | Keep existing contents |
| `TruncateExisting` | Error | Truncate |
| `OpenOrCreate` | Create | Keep existing contents |
| `CreateOrTruncate` | Create | Truncate |
| `CreateNew` | Create | Error |

Writes start at offset zero unless `append=true`. Without truncation, any old
tail beyond the new bytes remains. Append is independent of creation mode:
use `create_mode=OpenOrCreate, append=true` to append while preserving old data.
The default `CreateOrTruncate` still truncates with `append=true`.

`SyncMode` is `NoSync | Data | Full`: no synchronization, data plus metadata
needed to retrieve it, or data plus all file metadata. POSIX uses
`O_DSYNC`/`O_SYNC`; Windows maps both `Data` and `Full` to write-through I/O.
Permissions are masked by POSIX umask on creation and ignored on Windows.
`read_file(sync_timestamp=true)` synchronizes the file after reading; Windows
requires write access for this option because it uses `FlushFileBuffers`.

`FileKind` is `Unknown | Regular | Directory | SymLink | Socket | Pipe |
BlockDevice | CharDevice`. Missing paths raise; `Unknown` is not a missing-path
sentinel. `mtime` returns seconds since the Unix epoch and nanoseconds within
that second (`0 <= nanoseconds < 1_000_000_000`), including negative seconds.
`file_size` follows links and requires a regular file.

`exists` returns false for missing paths but raises for other errors. The
`can_*` probes also return false for denied access; they are point-in-time
checks, not a guarantee that a later operation will succeed. `can_execute` is
a POSIX access check or Windows `FILE_EXECUTE` check, not an executable suffix
or owner-execute-bit classification.

`mkdir(recursive=true)` creates missing parents but still raises when the final
directory already exists, matching async 0.21.2. `remove` unlinks files and links;
`rmdir` removes directories, optionally with their contents. Both raise for
missing paths. `rmdir` rejects a symlink/junction as its root and does not traverse
links found in the tree.

`readdir` returns names, not full paths. Hidden means a leading dot on POSIX and
the hidden attribute on Windows. Special entries are `.` and `..`; on POSIX,
excluding hidden entries also excludes these names. Sorting uses `Array::sort`,
as in async (length-first String ordering, then code units).

## Synchronous extensions and migration

The following helpers remain outside the async-aligned core:

- `remove_all(path)` removes files, links, or directory trees and ignores missing
  paths. Use `rmdir(recursive=true)` when a directory is required.
- `hardlink(src, dst)` creates a fresh destination. An existing destination
  raises an error recognized by `is_EEXIST()`. Failures never remove either path.
- `readlink(path)` returns the stored target on POSIX and Windows, preserving
  relative and dangling links. Windows also supports directory junctions.
  Absolute Windows targets retain the `\\?\` prefix, including volume GUID
  and UNC paths; relative targets are returned unchanged.
  Use `realpath` to resolve an existing target.
- `touch(path)` updates an existing file's timestamp; it does not create a file.
- `set_executable(path)` adds POSIX execute bits; it is a no-op on Windows.

| Previous API | Replacement |
| --- | --- |
| `read_bytes` / `write_bytes` | `read_file` / `write_file` with `Bytes` |
| Text `read_file` / `write_file` | Decode / encode UTF-8 explicitly around byte I/O |
| `append_bytes` / `append_file` | `write_file(..., create_mode=OpenOrCreate, append=true)` |
| `size` | `file_size` |
| `mtime -> Int64` | `mtime -> (Int64, Int)` |
| `path_kind` / `PathKind` | `kind` / `FileKind`; use `follow_symlink=false` for link metadata |
| `stat` / `FileStat` | `mtime` and `file_size` |
| `mkdir_p` | `mkdir(..., recursive=true)`; handle an existing final directory explicitly |

Moon's `src/util/os` facade owns `stat_into`, `hardlink_many`, `list_dir` and
`DirEntry`, along with text helpers, error fallbacks, unsynchronized writes,
and NAR owner-execute-bit policy. Batch replacement is a compiler cache policy.
These helpers are not exported by the standalone unix module. File handles, streaming,
watching, and other async-only operations are outside this pass.

On Windows, `realpath` returns drive-absolute paths such as `C:\dir\file` and
regular UNC paths such as `\\server\share\file`, matching async/fs. It preserves
the extended prefix for other namespaces instead of returning a relative path.

The Windows UNC integration test uses `MOON_UNIX_TEST_UNC_ROOT`, which must name
a writable SMB share such as `\\localhost\unix-tests`. CI creates and removes a
temporary share for this test; local runs without that variable omit this case.

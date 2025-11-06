# Path Utilities for POSIX Systems

This package provides path manipulation utilities specifically designed for POSIX-compliant systems (Unix, Linux, macOS). It handles paths using forward slashes (`/`) as the path separator.

## Overview

The package offers a complete set of functions for working with file paths:

- Path decomposition: `basename`, `dirname`, `extname`
- Path testing: `is_absolute`
- Path construction: `join`
- Path transformation: `normalize`, `relative`, `resolve`
- Platform constants: `sep`, `delimiter`

## Basic Path Operations

### Basename and Dirname

Extract the last component of a path or get the directory part:

```moonbit
///|
test "basename and dirname examples" {
  // Get the last component (filename)
  inspect(@posix.basename("usr/local/bin"), content="bin")
  inspect(@posix.basename("project/src/main.mbt"), content="main.mbt")

  // Get the directory part
  inspect(@posix.dirname("usr/local/bin"), content="usr/local")
  inspect(@posix.dirname("project/src/main.mbt"), content="project/src")

  // Handle trailing slashes
  inspect(@posix.basename("usr/local/"), content="")
  inspect(@posix.dirname("usr/local/"), content="usr/local")
}
```

### Extension Name

Extract file extensions from paths:

```moonbit
///|
test "extension extraction" {
  // Get file extension including the dot
  inspect(@posix.extname("document.txt"), content=".txt")
  inspect(@posix.extname("archive.tar.gz"), content=".gz")
  inspect(@posix.extname("project/main.mbt.md"), content=".md")

  // Files without extensions
  inspect(@posix.extname("README"), content="")
  inspect(@posix.extname("project/"), content="")
}
```

## Path Testing

### Absolute Path Detection

Determine if a path is absolute (starts with `/`):

```moonbit
///|
test "absolute path detection" {
  // Absolute paths start with /
  @json.inspect(@posix.is_absolute("/home/user"), content=true)
  @json.inspect(@posix.is_absolute("/usr/local/bin"), content=true)

  // Relative paths
  @json.inspect(@posix.is_absolute("home/user"), content=false)
  @json.inspect(@posix.is_absolute("../project"), content=false)
  @json.inspect(@posix.is_absolute(""), content=false)
}
```

## Path Construction

### Joining Paths

Combine path components with proper separator handling:

```moonbit
///|
test "path joining" {
  // Basic joining
  inspect(@posix.join("usr", "local"), content="usr/local")
  inspect(@posix.join("project", "src"), content="project/src")

  // Handle trailing slashes
  inspect(@posix.join("usr/", "local"), content="usr/local")

  // Absolute paths override
  inspect(@posix.join("relative", "/absolute"), content="/absolute")
}
```

## Path Transformation

### Normalization

Clean up redundant components and resolve `.` and `..`:

```moonbit
///|
test "path normalization" {
  // Remove redundant components
  inspect(@posix.normalize("a/./b/../c/"), content="a/c")
  inspect(@posix.normalize("/usr/local/../bin"), content="/usr/bin")

  // Handle complex cases
  inspect(@posix.normalize("/a/b/../../c/."), content="/c")
  inspect(@posix.normalize("a/b/c/.."), content="a/b")
}
```

### Relative Paths

Calculate the relative path between two locations:

```moonbit
///|
test "relative path calculation" {
  // Same directory level
  let from = "/home/user_name"
  let to = "/home/user_name/proj_a"
  inspect(@posix.relative(from, to), content="proj_a")

  // Go up one level
  let from2 = "/home/user_name/proj_a"
  let to2 = "/home/user_name"
  inspect(@posix.relative(from2, to2), content="..")

  // Same path
  let from3 = "/home/user_name"
  let to3 = "/home/user_name"
  inspect(@posix.relative(from3, to3), content="")

  // Sibling directories
  let from4 = "/home/user_name/proj_a"
  let to4 = "/home/user_name/proj_b"
  inspect(@posix.relative(from4, to4), content="../proj_b")
}
```

### Path Resolution

Convert relative paths to absolute paths and normalize them:

```moonbit
///|
test "path resolution" {
  // Resolve and normalize absolute paths
  inspect(@posix.resolve("/usr/../home/user"), content="/home/user")
  inspect(@posix.resolve("/a/b/c/../../.."), content="/")

  // Note: resolve() with relative paths depends on current working directory
  // and will join with the current directory before normalizing
}
```

## Platform Constants

The package provides platform-specific constants:

```moonbit
///|
test "platform constants" {
  // Path component separator
  inspect(@posix.sep, content="/")

  // Path list delimiter (for PATH environment variable)
  inspect(@posix.delimiter, content=":")
}
```

## Key Properties

The package maintains several important properties:

1. **Basename/Dirname relationship**: For most paths, joining dirname and basename gives the original path
2. **Relative/Join relationship**: `join(from, relative(from, to))` equals `normalize(to)`
3. **Idempotent normalization**: `normalize(normalize(path))` equals `normalize(path)`

## Edge Cases

The implementation handles various edge cases consistently:

- Empty paths are handled appropriately
- Trailing slashes are preserved where semantically important
- Double leading slashes (`//`) are preserved per POSIX standards
- The functions are consistent with Python's `os.path` module behavior rather than strict POSIX compliance where they differ

This makes the package reliable for real-world path manipulation in POSIX environments.
# Path Utilities for Windows Systems

This package provides path manipulation utilities specifically designed for Windows systems. It handles paths using backslashes (`\`) as the path separator and supports various Windows path formats including UNC paths, device paths, and volume identifiers.

## Overview

The package offers a complete set of functions for working with Windows file paths:

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
  inspect(@win32.basename("C:\\Users\\user"), content="user")
  inspect(@win32.basename("project\\src\\main.mbt"), content="main.mbt")

  // Get the directory part
  inspect(@win32.dirname("C:\\Users\\user"), content="C:\\Users")
  inspect(@win32.dirname("project\\src\\main.mbt"), content="project\\src")

  // Handle trailing backslashes
  inspect(@win32.basename("C:\\Users\\"), content="")
  inspect(@win32.dirname("C:\\Users\\"), content="C:\\Users")
}
```

### Extension Name

Extract file extensions from paths:

```moonbit
///|
test "extension extraction" {
  // Get file extension including the dot
  inspect(@win32.extname("document.txt"), content=".txt")
  inspect(@win32.extname("archive.tar.gz"), content=".gz")
  inspect(@win32.extname("project\\main.mbt.md"), content=".md")

  // Files without extensions
  inspect(@win32.extname("README"), content="")
  inspect(@win32.extname("project\\"), content="")
}
```

## Path Testing

### Absolute Path Detection

Windows has various types of absolute paths. The function correctly identifies them all:

```moonbit
///|
test "absolute path detection" {
  // Standard drive letter paths
  @json.inspect(@win32.is_absolute("C:\\"), content=true)
  @json.inspect(@win32.is_absolute("D:\\folder\\file"), content=true)

  // UNC paths (network shares)
  @json.inspect(@win32.is_absolute("\\\\server\\share\\file"), content=true)

  // Verbatim UNC paths
  @json.inspect(
    @win32.is_absolute("\\\\?\\UNC\\server\\share\\file"),
    content=true,
  )

  // Verbatim drive letter paths
  @json.inspect(@win32.is_absolute("\\\\?\\C:\\file"), content=true)

  // Volume GUID paths
  @json.inspect(
    @win32.is_absolute(
      "\\\\?\\Volume{12345678-1234-1234-1234-1234567890ab}\\file",
    ),
    content=true,
  )

  // Device namespace paths
  @json.inspect(@win32.is_absolute("\\\\.\\COM56"), content=true)

  // Verbatim symlink paths
  @json.inspect(@win32.is_absolute("\\\\?\\GLOBALROOT\\file"), content=true)

  // Relative paths
  @json.inspect(@win32.is_absolute("C:folder\\file"), content=false) // Drive-relative
  @json.inspect(@win32.is_absolute("Users\\user"), content=false)
  @json.inspect(@win32.is_absolute(""), content=false)
}
```

## Path Construction

### Joining Paths

Combine path components with proper separator handling:

```moonbit
///|
test "path joining" {
  // Basic joining
  inspect(@win32.join("Users", "user"), content="Users\\user")
  inspect(@win32.join("project", "src"), content="project\\src")

  // Handle trailing backslashes
  inspect(@win32.join("Users\\", "user"), content="Users\\user")

  // Absolute paths override
  inspect(@win32.join("relative", "\\absolute"), content="\\absolute")
}
```

## Path Transformation

### Normalization

Clean up redundant components and resolve `.` and `..`:

```moonbit
///|
test "path normalization" {
  // Remove redundant components
  inspect(@win32.normalize("a\\.\\b\\..\\c\\"), content="a\\c")
  inspect(@win32.normalize("C:\\Users\\..\\Windows"), content="C:\\Windows")

  // Handle complex cases
  inspect(@win32.normalize("\\a\\b\\..\\..\\c\\."), content="\\c")
  inspect(@win32.normalize("a\\b\\c\\.."), content="a\\b")
}
```

### Relative Paths

Calculate the relative path between two Windows locations:

```moonbit
///|
test "relative path calculation" {
  // Same directory level
  let from = "C:\\Users\\user_name"
  let to = "C:\\Users\\user_name\\proj_a"
  inspect(@win32.relative(from, to), content="proj_a")

  // Go up one level
  let from2 = "C:\\Users\\user_name\\proj_a"
  let to2 = "C:\\Users\\user_name"
  inspect(@win32.relative(from2, to2), content="..")

  // Same path
  let from3 = "C:\\Users\\user_name"
  let to3 = "C:\\Users\\user_name"
  inspect(@win32.relative(from3, to3), content="")

  // Sibling directories
  let from4 = "C:\\Users\\user_name\\proj_a"
  let to4 = "C:\\Users\\user_name\\proj_b"
  inspect(@win32.relative(from4, to4), content="..\\proj_b")
}
```

### Path Resolution

Convert relative paths to absolute paths and normalize them:

```moonbit
///|
test "path resolution" {
  // Resolve and normalize absolute paths
  inspect(
    @win32.resolve("\\Users\\..\\Windows\\System32"),
    content="\\Windows\\System32",
  )
  inspect(@win32.resolve("\\a\\b\\c\\..\\..\\.."), content="\\")

  // Note: resolve() with relative paths depends on current working directory
  // and will join with the current directory before normalizing
}
```

## Platform Constants

The package provides Windows-specific constants:

```moonbit
///|
test "platform constants" {
  // Path component separator
  inspect(@win32.sep, content="\\")

  // Path list delimiter (for PATH environment variable)
  inspect(@win32.delimiter, content=";")
}
```

## Windows Path Types

Windows supports several types of absolute paths:

1. **Drive Letter Paths**: `C:\folder\file`
2. **UNC Paths**: `\\server\share\file` (network shares)
3. **Verbatim Paths**: `\\?\C:\file` (bypass path processing)
4. **Verbatim UNC**: `\\?\UNC\server\share\file`
5. **Volume GUID**: `\\?\Volume{guid}\file`
6. **Device Paths**: `\\.\device`
7. **Symlink Paths**: `\\?\GLOBALROOT\file`

The `is_absolute` function correctly identifies all these formats.

## Key Properties

The package maintains several important properties:

1. **Basename/Dirname relationship**: For most paths, joining dirname and basename gives the original path
2. **Relative/Join relationship**: `join(from, relative(from, to))` equals `normalize(to)`
3. **Idempotent normalization**: `normalize(normalize(path))` equals `normalize(path)`

## Edge Cases

The implementation handles various Windows-specific edge cases:

- Drive-relative paths (`C:folder`) are treated as relative, not absolute
- Empty paths return appropriate default values
- Trailing backslashes are preserved where semantically important
- All Windows path prefix types are properly recognized
- The functions are consistent with Python's `os.path` module behavior

This makes the package reliable for real-world path manipulation in Windows environments, handling the complexity of Windows path formats while providing a clean, consistent API.
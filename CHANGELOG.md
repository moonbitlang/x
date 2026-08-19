# Changelog

## [Unreleased]

## [0.5.1]

### Added

- Added non-deprecated `Path::to_string` method access to `@path` (#306).

## [0.5.0]

### Added

- Added MD4, RIPEMD-160, SHA-384 and SHA-512 hashing (with streaming
  contexts) and an AES-128/192/256 block cipher with ECB/CBC modes to
  `@crypto`, ported from `mbtexcel` (#298)
- Added `SHA224` with a streaming context implementing `CryptoHasher`, so
  SHA-224 no longer requires the deprecated `reg` parameter of `SHA256::new`
  (#298)
- Added `@unicode.to_utf8_bytes` and `@unicode.to_utf8_string` for UTF-8
  conversion, and `@unicode.char_to_utf16_pair` to split a supplementary char
  into a UTF-16 surrogate pair (#304)
- Added `@unicode.CharClass`, a compact character range set with constant-time
  BMP lookup backed by a bitset, and the JSON5 character classification tables
  (`non_ascii_whitespace`, `non_ascii_id_start`, `non_ascii_id_continue`)
  (#304)

### Changed

- Moved the UTF-8 conversion helpers out of the internal FFI layer into
  `@unicode`; `@fs` now uses them directly (#304)

### Fixed

- Fixed deprecation warnings from trait method extension calls in
  `@rational`, `@time`, `@path`, `@uuid`, and `@decimal` (#302)
- Hardened `@crypto` AES, ChaCha, and SHA-512 handling for side-channel,
  counter-exhaustion, and message-length edge cases. (#298)

### Deprecated

- Deprecated the `reg` parameter of `SHA256::new`; to compute SHA-224, use
  `SHA224::new()` instead (#298)
- Deprecated `@encoding.encode_to` and `@encoding.to_utf16_bytes` in favor of
  `Buffer::write_string_utf8/utf16le/utf16be` and `@encoding.to_utf16le_bytes`,
  and deprecated `@encoding.write_utf8_char`, `write_utf16_char`,
  `write_utf16le_char`, and `write_utf16be_char` in favor of the corresponding
  `Buffer::write_char_utf8/utf16le/utf16be` methods (#304)

## [0.4.50]

### Added

- Added `@unicode` package with per-character Unicode simple case folding to
  lowercase, following Node.js `toLowerCase` (#296)
- Added `@unicode.utf16_pair_to_char` to combine a UTF-16 surrogate pair
  into a char (#297)

### Fixed

- Fixed `@path` win32 relative path comparisons to use full Unicode case
  folding (#296)
- Fixed compiler warnings in `@json5`, `@path`, and `@time` with MoonBit
  0.1.20260807 (#295)

### Changed

- Improved `@rational` comparison to avoid `BigInt` allocation, keeping
  cross-multiplication in fixed-width arithmetic when safe

## [0.4.49]

### Fixed

- Fixed `@rational` comparison overflowing silently for fixed-width integer
  values, and made `@rational.new` return `None` when the reduced form does not
  fit the target integer type (#291)

## [0.4.48]

### Changed

- Updated MoonBit toolchain support to 20260803

### Deprecated

- Deprecated `@sys.get_cli_args`, `@sys.get_env_vars`, `@sys.get_env_var`,
  `@sys.set_env_var`, and `@sys.unset_env_var` in favor of the `@env` package

## [0.4.47]

### Added

- Added `AGENTS.md` with repository guidance for agent contributions (#283)

### Changed

- Improved `@crypto` performance with SIMD-accelerated MD5, SHA-1, SHA-256,
  SM3, ChaCha, and HMAC

### Fixed

- Fixed `@path` win32 handling of verbatim prefixes, rooted paths, and UNC cwd
- Fixed `@fs` and `@sys` native FFI to use wide (Unicode) Windows APIs

## [0.4.46]

### Changed

- Aligned `@path` posix and win32 behavior with the Node.js `path` module

## [0.4.45]

### Added

- Added `Debug` implementations for common value types in `@decimal`,
  `@encoding`, `@json5`, `@path`, `@stack`, `@time`, and `@uuid` (#250)

## [0.4.44]

### Added

- Added `Debug` implementation for `@rational` (#237)

### Fixed

- Fixed `@fs` JS backend imports to use MoonBit import annotations and Node's
  `node:fs`, preserving ESM/CJS output format (#248)
- Fixed `@json5` support for debug assertions (#237)

### Changed

- Removed deprecated `@benchmark` package (#237)
- Removed deprecated `Show` implementations (#237)
- Improved performance for `@json5` (#240), `@path` (#244), `@time` (#246),
  and `@uuid` (#243)
- Updated MoonBit toolchain support and refreshed interface files (#239, #240)

## [0.4.43]

### Fixed

- Fixed `Path::join` to ignore empty components
- Kept `Show` implementation for `@time.Weekday` (#232)

## [0.4.42]

### Fixed

- Fixed `Path::resolve` to normalize joined relative paths (#232)
- Cleaned up deprecated `@strconv` usages (#232)

### Changed

- Switched to derived `Debug` implementations and deprecated `Show`
  implementations (#232)

## [0.4.41]

### Changed

- Updated MoonBit toolchain support to 20260310 and migrated package manifests
  to `moon.pkg` (#230)

## [0.4.40]

### Changed

- Updated MoonBit toolchain support to v0.7.2 (#224)

## [0.4.39]

### Fixed

- Fixed the type of `@sys.exit` for native ffi (#221)

### Changed

- Updated MoonBit toolchain support to v0.7.1 (#223)

## [0.4.38]

### Fixed

- Fix path library `basename` and `dirname` for some edge cases (#211)

## [0.4.37]

### Added

- Added `@path` package for path handling (#208)
- Added `@sys.get_env_var` for accessing single environment varialbe (#201)
- Added `@codec/base64` (#174)

### Fixed

- The `read_dir` for native backend will not skip hidden files/diretories (#210)

### Changed

- Updated MoonBit toolchain support to v0.6.32 (#209)

## [0.4.36]

### Changed

- Prepare for next MoonBit toolchain support (#197)

## [0.4.35]

### Added

- Added `@decimal` package for arbitrary precision decimal (#183)

### Changed

- Updated MoonBit toolchain support to v0.6.29 (#183, #195)
- `@time` package is rewritten to use `lexmatch` (#194)

## [0.4.34]

### Fixed

- Updated MoonBit toolchain support to 0.6.26, updated C FFI annotations (#181)
- Improved performance on `@crypto.uint_to_hex_string` (#179)

## [0.4.33]

### Fixed

- Updated MoonBit toolchain support to 0.6.26, updated info file (#180)

### Changed

- Deprecated `bench` package. It is suggested to use the
  [builtin benchmark](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)
  functionality (#177)

## [0.4.32]

### Added

- Added `ByteSource` trait for `@crypto` such that it accepts `FixedArray[Byte]`
  `Bytes` `@bytes.View` at the same time. (#165)
- Added `CryptoHasher` trait for `@crypto` (#142)
- Added `hmac` support based on `CryptoHasher` (#142)

### Fixed

- Updated the READMEs by switching to `.mbt.md` format (#164)
- Fixed the overflow for rational's equality check (#167)
- Refactored ChaCha series to make them faster (#170)
- Updated MoonBit toolchain support to 0.6.22, updated info file (#169)
- Updated MoonBit toolchain support to 0.6.24, updated info file (#175)

### Changed

- Deprecated `Num` trait since it has never been open and no one can implement
  it (#164)
- Deprecated `Stack::peek_exn` and replace it with `Stack::unsafe_peek` (#164)
- Renamed `MD5Context` to `MD5`, `SM3Context` to `SM3`, `Sha256Context` to
  `Sha256` in `@crypto` (#142)
- `SHA256` and `SM3` can now `update` after `finalize` (#169)
- Deprecated `@crypto.chachax` series and replace them with `@crypto.ChaCha`
  (#173)

## [0.4.31]

### Added

- Added `@rational` package, which was in the core library (#161)
- Added `Stack::from_iter` `Stack::iter` for conversion between different data
  (#162)

### Fixed

- Updated MoonBit toolchain support to 0.6.21, including syntax and the String
  APIs used internally (#162)

### Changed

- Deprecated `Stack::from_list` `Stack::push_list` `Stack::to_list` since the
  `@immut/list` is deprecated (#162)
- Updated the license headers to year 2025 (#162)

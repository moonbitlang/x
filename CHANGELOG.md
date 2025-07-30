# Changelog

## [Unreleased]

### Added

- Added `ByteSource` trait for `@crypto` such that it accepts `FixedArray[Byte]`
  `Bytes` `@bytes.View` at the same time. (#165)
- Added `CryptoHasher` trait for `@crypto` (#142)
- Added `hmac` support based on `CryptoHasher` (#142)

### Fixed

- Updated the READMEs by switching to `.mbt.md` format (#164)
- Fixed the overflow for rational's equality check (#167)
- Updated MoonBit toolchain support to 0.6.22, updated info file (#169)

### Changed

- Deprecated `Num` trait since it has never been open and no one can implement
  it (#164)
- Deprecated `Stack::peek_exn` and replace it with `Stack::unsafe_peek` (#164)
- Renamed `MD5Context` to `MD5`, `SM3Context` to `SM3`, `Sha256Context` to
  `Sha256` in `@crypto` (#142)
- `SHA256` and `SM3` can now `update` after `finalize` (#169) 

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

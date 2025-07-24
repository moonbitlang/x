# Changelog

## [Unreleased]

### Fixed

- Updated the READMEs by switching to `.mbt.md` format

### Changed

- Deprecated `Num` trait since it has never been open and no one can implement it

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

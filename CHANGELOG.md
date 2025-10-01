# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0

### Changed

- Depends on `lumberjack` 2.0 or greater.
- A lot of the functionality has been moved to `Lumberjack::Device::Test` in the `lumberjack` gem. The `Lumberjack::CaptureDevice` class now inherits from `Lumberjack::Device::Test` and adds some additional functionality on top of it.

### Removed

- The RSpec matcher `include_log_entry` has been moved to its own gem.
- Entry scoring logic for closest match has been removed and is now handled by the `lumberjack` gem.

### Deprecated

- The `level` parameter on `include?`, `match`, `extract`, and `closest_match` is deprecated. Use `severity` instead. The `level` parameter will be removed in version 2.1 but will continue to work as an alias for `severity` until then.
- The `tags` parameter on `include?`, `match`, `extract`, and `closest_match` is deprecated. Use `attributes` instead. The `tags` parameter will be removed in version 2.1 but will continue to work as an alias for `attributes` until then

## 1.2.2

### Changed

- Improved failure message on RSpec matcher.

### Added

- `Lumberjack::CaptureDevice` now acts as an enumerable object.
- Exposed helper methods for formatting log entries.

## 1.2.1

### Changed

- Improve failure message for RSpec matcher by removing values that were not included in the original expectation.

## 1.2.0

### Added

- Added support for matching the `progname` of log entries.
- Added custom RSpec matchers that outputs cleaner messages for failed tests.

## 1.1.1

### Fixed

- Handle tag array comparison when an array contains hashes to consistently convert the hash keys to strings. Otherwise array hashes were being treated differently that other tag structures.

### Changed

- Improved the `inspect` method to provide a clearer representation of captured log entries to make debugging tests easier.

## 1.1.0

### Added

- Support for matching tag structures in log entries regardless of if they are specified with dot notation or nested tags. So "foo.bar" will match a tag with the structure `{foo: {bar: "value"}}` or `{"foo.bar" => value}`.

### Changed

- Specifying a tag to match on nil will now match log entries missing the tag rather than matching any value for that tag.

## 1.0.1

### Added

- Ruby 3 compatibility

## 1.0.0

### Added

- Initial release.

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.1

### Fixed

- `include?` now symbolizes filter keys and raises an `ArgumentError` on unrecognized filter keys. Previously filters with string keys or misspelled keys were silently ignored, causing the method to match any captured entry.
- `capture_logger_around_example` now correctly adds the rspec metadata attributes to entries written to the underlying device when an example fails. Previously the attributes were silently dropped and building them raised a `NoMethodError` since `RSpec::Core::Example` does not have a `source_location` method; the example location is now recorded in the `rspec.location` attribute.
- `write_to_underlying_device` accepts an optional `attributes` keyword argument to add attributes to each entry as it is written.
- The `include_log_entry` RSpec matcher now works with plain `Lumberjack::Device::Test` devices when using the deprecated `:level` and `:tags` options instead of raising an `ArgumentError`.
- The `max_entries` option is no longer ignored when initializing a `Lumberjack::CaptureDevice`.
- Fixed missing line break after "Closest match found:" in RSpec matcher failure messages.
- `each` and `length` now read from a thread safe copy of the entries buffer.

### Removed

- Removed unused internal `Lumberjack::CaptureDevice::EntryScore` class. It was never loaded and was replaced by the scoring logic in the lumberjack gem.

## 2.0.0

### Added

- Captured log entries are now passed through to the underlying logging device when the capture block is finished. This can be disabled by passing `write_to_original: false` to the `capture` method. You can then write the captured entries to the underlying device manually by calling `write_to_underlying_device`.
- Added `capture_logger_around_example` RSpec helper method to simplify capturing log entries in an `around` hook.

### Changed

- Depends on `lumberjack` 2.0 or greater.

### Deprecated

- The `:level` and `:tags` options on the matching methods (`include?`, `match`, `closest_match`, and `extract`) have been deprecated in favor of `:severity` and `:attributes`.

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

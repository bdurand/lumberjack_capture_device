# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.1

### Fixed

- Handle tag array comparison when an array contains hashes to consistently convert the hash keys to strings. Otherwise array hashes were being treated differently that other tag structures.

### Changed

- Improved the `inspect` method to provide a clearer representation of captured log entries to make debugging tests easier.

## 1.1.0

### Added

- Support for matching tag structures in log entries regardless of if they are specified with dot notation or nested tags. So "foo.bar" will match a tag with the structure `{foo: {bar: "value"}}` or `{"foo.bar" => value}`.

## 1.0.1

### Added

- Ruby 3 compatibility

## 1.0.0

### Added

- Initial release.

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0

### Added

- Support for nested tag structures in log entries. Now comparisons on tags will use dot notation to dereference nested tags. So "foo.bar" will match a tag with the structure `{foo: {bar: "value"}}`. This provides compatibility with an internal change in Lumberjack 1.3.

## 1.0.1

### Added

- Ruby 3 compatibility

## 1.0.0

### Added

- Initial release.

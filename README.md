# Lumberjack Capture Device

[![Continuous Integration](https://github.com/bdurand/lumberjack_capture_device/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack_capture_device/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/lumberjack_capture_device.svg)](https://badge.fury.io/rb/lumberjack_capture_device)

This is a plugin device for the [lumberjack gem](https://github.com/bdurand/lumberjack) that enables capturing log messages in a test suite so that assertions can be made against them. It provides an easy and stable method of testing that specific log messages are being sent to a logger.

Using mocks and stubs on a logger to test that it receives messages can make for a brittle test suite since there can be a wide variety of code writing messages to logs and your test suite may have a higher log level turned on causing it to skip messages at a lower level.

For instance, this RSpec code can break if any of the code called by `do_something` writes a different info log message:

```ruby
do_something
expect(Rails.logger).to receive(:info).with("Something happened")
```

It will also break if the test suite logger has the log level set to `warn` or higher since it will then skip all info and debug messages.

## Usage

You can call the `Lumberjack::CaptureDevice.capture` method to temporarily override a logger so that it will capture log entries within a block to an in-memory buffer. This method will yield the capturing log device and also return it as the result of the method. The log level will also be temporarily set to debug within the block, so you can capture all log messages without having to change the log level for the entire test suite.

You can use the `include?` method on the log device to determine if specific log entries were made. This would be the equivalent code to the above RSpec test, but without the brittleness of mocking method calls:

```ruby
Lumberjack::CaptureDevice.capture(Rails.logger) do |logs|
  do_something
  expect(logs).to include(level: :info, message: "Something happened")
end
```

You can also write that same test as:

```ruby
logs = Lumberjack::CaptureDevice.capture(Rails.logger) { do_something }
expect(logs).to include(level: :info, message: "Something happened")
```

For MiniTest, you could assert:

```ruby
logs = Lumberjack::CaptureDevice.capture(Rails.logger) { do_something }
assert(logs.include?(level: :info, message: "Something happened"))
```

You can filter the logs on level, message, and attributes.

- The level option can take either a label (i.e. `:warn`) or a constant (i.e. `Logger::WARN`).
- The message filter can be either an exact string or a regular expression, or any matcher supported by your test library.
- The attributes argument can match attributes with a Hash mapping attribute names to the matcher values. If attributes are nested, you can use dot notation on attribute names to reference nested attributes.

```ruby
expect(logs).to include(level: :info, message: /something/i)
expect(logs).to include(level: Logger::INFO, attributes: {foo: "bar"})
expect(logs).to include(attributes: {foo: anything, count: {one: 1}})
expect(logs).to include(attributes: {foo: anything, "count.one" => 1})
```

You can also use the `Lumberjack::CaptureDevice#extract` method with the same arguments as used by `include?` to extract all log entries that match the filters. You can get all of the log entries with `Lumberjack::CaptureDevice#buffer`.

### RSpec Support

You can include some RSpec syntactic sugar by requiring the rspec file in your test helper.

```ruby
require "lumberjack/capture_device/rspec"
```

This will give you a `capture_logger` method and `include_log_entry` matcher. The `include_log_entry` matcher provides a bit cleaner output which can make debugging failing tests a bit easier.

```ruby
describe MyClass do
  it "logs information" do
    logs = capture_logger(Rails.logger) { MyClass.do_something }
    expect(logs).to include_log_entry(message: "Something")
  end
end
```

When the matcher fails, the failure message includes a diff between the expectation and the closest matching entry so you can see exactly which fields and attributes are off. Lines prefixed with `-` show what was expected and lines prefixed with `+` show what was actually logged.

```
expected logs to include entry:
  severity: WARN
  message: User logged out
  attributes: request_id: "abc"
              user.role: "admin"

Closest match found (- expected, + actual):
  - severity: WARN
  + severity: INFO
    message: "User logged out"
  - attributes.user.role: "admin"
  + attributes.user.role: "guest"
    attributes.duration: 1.5
  - attributes.request_id: "abc"
  + attributes.request_id: (not set)
```

You can also set up log capturing around each example with the `capture_logger_around_example` method.

```ruby
describe MyClass do
  around do |example|
    capture_logger_around_example(Rails.logger, example)
  end

  it "logs information" do
    MyClass.do_something
    expect(Rails.logger).to include_log_entry(message: "Something")
  end
end
```

> [!TIP]
> Add `capture_logger_around_example` as a global `around` hook in your RSpec configuration to automatically capture log entries for every example.
>
> This will also suppress all log output during tests unless an example fails which can reduce noise in the logs from tests that don't fail. This is especially useful in CI environments where you can save the logs as an artifact for failed test runs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lumberjack_capture_device'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install lumberjack_capture_device
```

## Contributing

Open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

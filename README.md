[![Continuous Integration](https://github.com/bdurand/lumberjack_capture_device/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/lumberjack_capture_device/actions/workflows/continuous_integration.yml)
[![Maintainability](https://api.codeclimate.com/v1/badges/a0abc03721fff9b0cde1/maintainability)](https://codeclimate.com/github/bdurand/lumberjack/maintainability)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

# Lumberjack Capture Device

This is a plugin device for the [lumberjack gem](https://github.com/bdurand/lumberjack) that enables capturing log messages in a test suite so that assertions can be made against them. It provides and easy and stable method of testing that specific log messages are being sent to a logger.

Using mocks and stubs on a logger to test that it receives messages can make for a brittle test suite since there can a wide variety of code writing messages to logs and your test suite may have a higher log level turned on causing it skip messages at a lower level.

For instance, this rspec code can break is code anywhere else in the system writes an info log message:

```ruby
do_something
expect(Rail.logger).to receive(:info).with("Something happened")
```

It will also break if the test suite logger has the log level set to `warn` or higher since it will then skip all info and debug messages.

## Usage

You can override a logger's device inside a block with the `Lumberjack::CaptureDevice.capture` method. This method will yield the capturing log device which has an `include?` method you can use to make assertions about what was written to the log inside the block.

This would be the equivalent code to the above rspec test:

```ruby
Lumberjack::CaptureDevice.capture(Rails.logger) do |logs|
  do_something
  expect(logs).to include(level: :info, message: "Something happened")
end
```

The `capture` method also returns the device so you can also write that same test as:

```ruby
logs = Lumberjack::CaptureDevice.capture(Rails.logger) { do_something }
expect(logs).to include(level: :info, message: "Something happened")
```

The

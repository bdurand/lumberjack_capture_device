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

You can filter the logs on level, message, and tags.

- The level option can take either a label (i.e. `:warn`) or a constant (i.e. `Logger::WARN`).
- The message filter can be either an exact string or a regular expression, or any matcher supported by your test library.
- The tags argument can match tags with a Hash mapping tag names to the matcher values. If tags are nested, you can use dot notation on tag names to reference nested tags.

```ruby
expect(logs).to include(level: :info, message: /something/i)
expect(logs).to include(level: Logger::INFO, tags: {foo: "bar"})
expect(logs).to include(tags: {foo: anything, count: {one: 1}})
expect(logs).to include(tags: {foo: anything, "count.one" => 1})
```

You can also use the `Lumberjack::CaptureDevice#extract` method with the same arguments as used by `include?` to extract all log entries that match the filters. You can get all of the log entries with `Lumberjack::CaptureDevice#buffer`.

### Custom RSpec Matcher

You can also use the custom RSpec matcher. This matcher produces a bit cleaner output than the default RSpec include matcher and can make debugging tests easier.

```ruby
# In your main spec helper file
include "lumberjack/capture_device/rspec"

describe MyClass do
  it "logs information" do
    # It can be used on a captured logger directly
    logs = capture_logger { MyClass.do_something }
    expect(logs).to have_logged(message: "Something")
  end

  it "logs more things" do
    # It can also be called on a code block
    expect { MyClass.do_something }.to have_logged(message: "Something")
  end
end
```

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

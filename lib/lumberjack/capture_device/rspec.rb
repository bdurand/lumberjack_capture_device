# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"

# RSpec helper methods for working with CaptureDevice.
module Lumberjack::CaptureDevice::RSpec
  # Create a matcher for checking if a log entry is included in the captured logs.
  # This matcher provides better error messages than using the include? method directly.
  #
  # @param expected_hash [Hash] The expected log entry attributes to match.
  # @option expected_hash [String, Symbol, Integer] :severity The expected log severity.
  # @option expected_hash [String, Regexp] :message The expected message content.
  # @option expected_hash [Hash] :attributes Expected log entry attributes.
  # @option expected_hash [String] :progname Expected program name.
  # @return [Lumberjack::CaptureDevice::IncludeLogEntryMatcher] A matcher for the expected log entry.
  # @example
  #   expect(logs).to include_log_entry(severity: :info, message: "User logged in")
  # @example
  #   expect(logs).to include_log_entry(message: /error/i, attributes: {user_id: 123})
  def include_log_entry(expected_hash)
    Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(expected_hash)
  end

  # Capture log entries from a logger within a block. This method temporarily
  # replaces the logger's device with a CaptureDevice and sets the log level to debug.
  # The logger's formatters remain active, so captured entries contain the same
  # formatted values that would have been logged.
  #
  # @param logger [Lumberjack::Logger] The logger to capture entries from.
  # @yield [device] The block to execute while capturing log entries.
  # @yieldparam device [Lumberjack::CaptureDevice] The device that will capture the log entries.
  # @return [Lumberjack::CaptureDevice] The device that captured the log entries.
  # @example
  #   logs = capture_logger(Rails.logger) do
  #     Rails.logger.info("Test message")
  #   end
  #   expect(logs).to include_log_entry(severity: :info, message: "Test message")
  def capture_logger(logger, write_to_original: true, &block)
    Lumberjack::CaptureDevice.capture(logger, write_to_original: write_to_original, &block)
  end

  # RSpec around hook to automatically capture logs for each example. The captured logs are only
  # written to the original logger if the example fails. This helps keep the logs more usable for
  # debugging test failures since it removes all the noise from passing tests.
  #
  # This is designed for CI environments where you can save the logs as artifacts of the test run.
  #
  # @param logger [Lumberjack::Logger] The logger to capture entries for.
  # @param example [RSpec::Core::Example] The current RSpec example.
  #
  # @example Capture logs for a Rails application
  #  # In your spec_helper.rb or rails_helper.rb
  #  RSpec.configure do |config|
  #    config.around do |example|
  #      capture_logger_around_example(Rails.logger, example)
  #    end
  #  end
  def capture_logger_around_example(logger, example)
    capture_logger(logger, write_to_original: false) do |captured_device|
      example.run

      if example.exception
        rspec_attributes = {rspec: {location: example.location, description: example.metadata[:description]}}
        captured_device.write_to_underlying_device(attributes: rspec_attributes)
      end
    end
  end
end

RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

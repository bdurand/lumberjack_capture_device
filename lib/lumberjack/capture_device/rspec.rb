# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"

# RSpec helper methods for working with CaptureDevice.
module Lumberjack::CaptureDevice::RSpec
  # Create a matcher for checking if a log entry is included in the captured logs.
  # This matcher provides better error messages than using the include? method directly.
  #
  # @param expected_hash [Hash] The expected log entry attributes to match.
  # @option expected_hash [String, Symbol, Integer] :level The expected log level.
  # @option expected_hash [String, Symbol, Integer] :severity Alias for :level.
  # @option expected_hash [String, Regexp] :message The expected message content.
  # @option expected_hash [Hash] :attributes Expected log entry attributes.
  # @option expected_hash [Hash] :tags Alias for :attributes.
  # @option expected_hash [String] :progname Expected program name.
  # @return [Lumberjack::CaptureDevice::IncludeLogEntryMatcher] A matcher for the expected log entry.
  # @example
  #   expect(logs).to include_log_entry(level: :info, message: "User logged in")
  # @example
  #   expect(logs).to include_log_entry(message: /error/i, attributes: {user_id: 123})
  def include_log_entry(expected_hash)
    Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(expected_hash)
  end

  # Capture log entries from a logger within a block. This method temporarily
  # replaces the logger's device with a CaptureDevice, sets the log level to debug,
  # and removes formatters to capture raw log entries for testing.
  #
  # @param logger [Lumberjack::Logger] The logger to capture entries from.
  # @yield [device] The block to execute while capturing log entries.
  # @yieldparam device [Lumberjack::CaptureDevice] The device that will capture the log entries.
  # @return [Lumberjack::CaptureDevice] The device that captured the log entries.
  # @example
  #   logs = capture_logger(Rails.logger) do
  #     Rails.logger.info("Test message")
  #   end
  #   expect(logs).to include_log_entry(level: :info, message: "Test message")
  def capture_logger(logger, &block)
    Lumberjack::CaptureDevice.capture(logger, &block)
  end
end

RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

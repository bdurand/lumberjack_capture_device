# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"

# RSpec helper methods for working with CaptureDevice.
module Lumberjack::CaptureDevice::RSpec
  # Create a matcher for checking if a log entry is included in the captured logs.
  #
  # @param expected_hash [Hash] The expected log entry attributes to match.
  # @return [Lumberjack::CaptureDevice::IncludeLogEntryMatcher] A matcher for the expected log entry.
  def include_log_entry(expected_hash)
    Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(expected_hash)
  end

  # Capture log entries from a logger within a block.
  #
  # @param logger [Lumberjack::Logger] The logger to capture entries from.
  # @yield [device] The block to execute while capturing log entries.
  # @yieldparam device [Lumberjack::CaptureDevice] The device that will capture the log entries.
  # @return [Lumberjack::CaptureDevice] The device that captured the log entries.
  def capture_logger(logger, &block)
    Lumberjack::CaptureDevice.capture(logger, &block)
  end
end

RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

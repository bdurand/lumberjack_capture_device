# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"
require "lumberjack/rspec/include_log_entry_matcher"

# RSpec helper methods for working with CaptureDevice.
module Lumberjack::CaptureDevice::RSpec
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
    unless logger.is_a?(Lumberjack::ContextLogger)
      raise ArgumentError, "Expected a Logger, but received a #{logger.class}"
    end

    Lumberjack::CaptureDevice.capture(logger, &block)
  end
end

::RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"

module Lumberjack::CaptureDevice::RSpec
  def include_log_entry(expected_hash)
    Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(expected_hash)
  end

  def capture_logger(logger, &block)
    Lumberjack::CaptureDevice.capture(logger, &block)
  end
end

RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

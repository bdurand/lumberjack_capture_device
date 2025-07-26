# frozen_string_literal: true

require_relative "../capture_device"
require "rspec"

module Lumberjack::CaptureDevice::RSpec
  def have_logged(expected_hash)
    Lumberjack::CaptureDevice::HaveLoggedMatcher.new(expected_hash)
  end
end

RSpec.configure do |config|
  config.include Lumberjack::CaptureDevice::RSpec
end

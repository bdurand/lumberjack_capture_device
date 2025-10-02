# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::CaptureDevice::IncludeLogEntryMatcher do
  it "is a subclass of Lumberjack::RSpec::IncludeLogEntryMatcher" do
    expect(Lumberjack::CaptureDevice::IncludeLogEntryMatcher).to be < Lumberjack::RSpec::IncludeLogEntryMatcher
  end
end

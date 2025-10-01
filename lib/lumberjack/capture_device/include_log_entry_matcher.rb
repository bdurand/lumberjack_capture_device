# frozen_string_literal: true

# @deprecated Use Lumberjack::RSpec::IncludeLogEntryMatcher from the lumberjack_rspec gem instead.
#   This class will be removed in version 2.1.
class Lumberjack::CaptureDevice::IncludeLogEntryMatcher < Lumberjack::RSpec::IncludeLogEntryMatcher
  def initialize(expected_hash)
    Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice::IncludeLogEntryMatcher", "Lumberjack::CaptureDevice::IncludeLogEntryMatcher is now part of the the lumberjack_rspec gem. Use Lumberjack::RSpec::IncludeLogEntryMatcher instead.")
    super
  end
end

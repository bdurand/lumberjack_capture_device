# frozen_string_literal: true

require_relative("../lib/lumberjack_capture_device")
require_relative("../lib/lumberjack/capture_device/rspec")

require "stringio"

RSpec.configure do |config|
  config.warnings = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end

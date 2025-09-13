# frozen_string_literal: true

require "stringio"

require_relative("../lib/lumberjack_capture_device")
require_relative("../lib/lumberjack/capture_device/rspec")

Lumberjack.deprecation_mode = :raise

RSpec.configure do |config|
  config.warnings = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  config.around(:each, :deprecation_mode) do |example|
    Lumberjack::Utils.with_deprecation_mode(example.metadata[:deprecation_mode]) do
      example.run
    end
  end
end

# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

require "stringio"

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/"]
  end
rescue LoadError
end

require_relative("../lib/lumberjack_capture_device")
require_relative("../lib/lumberjack/capture_device/rspec")

Lumberjack.deprecation_mode = :raise

# Ruby 3.4 changed the format of Hash#inspect (`{"a" => 1}` instead of `{"a"=>1}`), so
# expectations on output that includes inspected hashes must be built using the same
# formatting as the Ruby version running the tests.
module HashInspectHelper
  # @param hash [Hash] The hash to inspect.
  # @return [String] The hash as it is rendered by Hash#inspect.
  def inspect_hash(hash)
    hash.inspect
  end

  # @param hash [Hash] The hash to inspect.
  # @return [String] The inspected hash without the surrounding braces.
  def inspect_hash_contents(hash)
    inspect_hash(hash).sub(/\A\{/, "").sub(/\}\z/, "")
  end
end

RSpec.configure do |config|
  config.warnings = true
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  config.include HashInspectHelper
  Kernel.srand config.seed

  config.around(:each, :deprecation_mode) do |example|
    Lumberjack::Utils.with_deprecation_mode(example.metadata[:deprecation_mode]) do
      example.run
    end
  end
end

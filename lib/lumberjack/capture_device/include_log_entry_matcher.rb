# frozen_string_literal: true

# RSpec matcher for checking captured logs for specific entries.
class Lumberjack::CaptureDevice::IncludeLogEntryMatcher
  # Initialize the matcher with expected log entry attributes.
  #
  # @param expected_hash [Hash] Expected log entry attributes to match against.
  def initialize(expected_hash)
    @expected_hash = normalize_expected_hash(expected_hash)
    @logger = nil
  end

  # Check if the logger contains a log entry matching the expected attributes.
  #
  # @param actual [Lumberjack::Logger, Lumberjack::ForkedLogger] The logger to check. The logger must be using
  #   a Lumberjack::Device::Test device.
  # @return [Boolean] True if a matching log entry is found.
  def matches?(actual)
    @logger = actual
    return false unless valid_logger?

    device = @logger.is_a?(Lumberjack::Device::Test) ? @logger : @logger.device
    device.include?(@expected_hash)
  end

  # Generate a failure message when the matcher fails.
  #
  # @return [String] A formatted failure message.
  def failure_message
    if valid_logger?
      formatted_failure_message(@logger, @expected_hash)
    else
      wrong_object_type_message(@logger)
    end
  end

  # Generate a failure message when the negated matcher fails.
  #
  # @return [String] A formatted failure message for negated expectations.
  def failure_message_when_negated
    if valid_logger?
      formatted_negated_failure_message(@logger, @expected_hash)
    else
      wrong_object_type_message(@logger)
    end
  end

  # Provide a description of what this matcher checks.
  #
  # @return [String] A human-readable description of the matcher.
  def description
    "have logged entry with #{expectation_description(@expected_hash)}"
  end

  private

  # Symbolize the expected hash keys and replace the deprecated :level and :tags
  # keys with :severity and :attributes so the hash can be passed to any
  # Lumberjack::Device::Test device.
  #
  # @param expected_hash [Hash] The expected log entry attributes.
  # @return [Hash] The normalized expected hash.
  def normalize_expected_hash(expected_hash)
    expected_hash = expected_hash.transform_keys(&:to_sym)

    if expected_hash.include?(:level)
      Lumberjack::Utils.deprecated("include_log_entry(level)", "include_log_entry level option has been renamed to severity; it will be removed in version 2.1.")
      level = expected_hash.delete(:level)
      expected_hash[:severity] = level unless expected_hash.include?(:severity)
    end

    if expected_hash.include?(:tags)
      Lumberjack::Utils.deprecated("include_log_entry(tags)", "include_log_entry tags option has been renamed to attributes; it will be removed in version 2.1.")
      tags = expected_hash.delete(:tags)
      expected_hash[:attributes] = tags unless expected_hash.include?(:attributes)
    end

    expected_hash
  end

  # Check if the logger is using a valid Lumberjack::Device::Test device.
  #
  # @return [Boolean] True if the logger is a Lumberjack::Device::Test.
  def valid_logger?
    return true if @logger.is_a?(Lumberjack::Device::Test)
    return false unless @logger.respond_to?(:device)

    @logger.device.is_a?(Lumberjack::Device::Test)
  end

  # Generate an error message for wrong object type.
  #
  # @param logger [Object] The object that was passed instead of a Lumberjack::Device::Test.
  # @return [String] An error message describing the type mismatch.
  def wrong_object_type_message(logger)
    unless logger.respond_to?(:device)
      return "Expected a Lumberjack::Logger object, but received a #{logger.class}."
    end

    device = logger.device
    "Expected logger device to be a Lumberjack::Device::Test, but it is a #{device.class}."
  end

  # Generate a detailed failure message showing expected vs actual logs.
  #
  # @param logger_or_device [Lumberjack::Device::Test] The logger device.
  # @param expected_hash [Hash] The expected log entry attributes.
  # @return [String] A formatted failure message with context.
  def formatted_failure_message(logger_or_device, expected_hash)
    device = logger_or_device.respond_to?(:device) ? logger_or_device.device : logger_or_device

    message = +"expected logs to include entry:\n" \
      "#{Lumberjack::Device::Test.formatted_expectation(expected_hash, indent: 2)}"

    closest_match = device.closest_match(**expected_hash)
    if closest_match
      message << "\n\nClosest match found:\n" \
        "#{Lumberjack::Device::Test.formatted_expectation(closest_match, indent: 2)}"
    end

    entries = device.entries
    message << "\n\nLogged #{entries.length} #{(entries.length == 1) ? "entry" : "entries"}"
    if entries.length > 0
      message << "\n----------------------\n"
      template = Lumberjack::LocalLogTemplate.new
      entries.each do |entry|
        message << "#{template.call(entry)}\n"
      end
    end

    message
  end

  # Generate a failure message for negated expectations.
  #
  # @param logger_or_device [Lumberjack::Device::Test] The logger to check.
  # @param expected_hash [Hash] The expected log entry attributes that should not be present.
  # @return [String] A formatted failure message for negated expectations.
  def formatted_negated_failure_message(logger_or_device, expected_hash)
    device = logger_or_device.respond_to?(:device) ? logger_or_device.device : logger_or_device
    message = "expected logs not to include entry:\n" \
      "#{Lumberjack::Device::Test.formatted_expectation(expected_hash, indent: 2)}"

    match = device.match(**expected_hash)
    if match
      message = "#{message}\n\nFound entry:\n" \
        "#{Lumberjack::Device::Test.formatted_expectation(match, indent: 2)}"
    end

    message
  end

  # Create a human-readable description of the expected log entry attributes.
  #
  # @param expected_hash [Hash] The expected log entry attributes.
  # @return [String] A formatted description of the expected attributes.
  def expectation_description(expected_hash)
    info = []
    info << "severity: #{formatted_value(expected_hash[:severity])}" unless expected_hash[:severity].nil?
    info << "message: #{formatted_value(expected_hash[:message])}" unless expected_hash[:message].nil?
    info << "progname: #{formatted_value(expected_hash[:progname])}" unless expected_hash[:progname].nil?

    expected_attributes = expected_hash[:attributes]
    if expected_attributes.is_a?(Hash)
      unless expected_attributes.empty?
        attributes = Lumberjack::Utils.flatten_attributes(expected_attributes)
        attributes_info = attributes.collect { |name, value| "#{name}=#{formatted_value(value)}" }.join(", ")
        info << "attributes: #{attributes_info}"
      end
    elsif expected_attributes
      # Matchers like RSpec's hash_including are matched against the attributes hash as a whole.
      info << "attributes: #{formatted_value(expected_attributes)}"
    end

    info.join(", ")
  end

  # Format a value for display in a description. Matcher objects (i.e. RSpec matchers)
  # that implement a +description+ method are displayed using that description since
  # inspecting them is not very informative.
  #
  # @param value [Object] The value to format.
  # @return [String] The formatted value.
  def formatted_value(value)
    if value.respond_to?(:description) && !value.is_a?(Module)
      value.description.to_s
    else
      value.inspect
    end
  end
end

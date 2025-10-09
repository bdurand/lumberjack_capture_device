# frozen_string_literal: true

# RSpec matcher for checking captured logs for specific entries.
class Lumberjack::CaptureDevice::IncludeLogEntryMatcher
  # Initialize the matcher with expected log entry attributes.
  #
  # @param expected_hash [Hash] Expected log entry attributes to match against.
  def initialize(expected_hash)
    @expected_hash = expected_hash.transform_keys(&:to_sym)
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

    # Handle deprecated keys
    if expected_hash.include?(:level) && !expected_hash.include?(:severity)
      expected_hash = expected_hash.merge(severity: expected_hash[:level])
    end
    if expected_hash.include?(:tags) && !expected_hash.include?(:attributes)
      expected_hash = expected_hash.merge(attributes: expected_hash[:tags])
    end

    message = +"expected logs to include entry:\n" \
      "#{Lumberjack::Device::Test.formatted_expectation(expected_hash, indent: 2)}"

    closest_match = device.closest_match(**expected_hash)
    if closest_match
      message << "\n\nClosest match found:" \
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
    info << "severity: #{expected_hash[:severity].inspect}" unless expected_hash[:severity].nil?
    info << "message: #{expected_hash[:message].inspect}" unless expected_hash[:message].nil?
    info << "progname: #{expected_hash[:progname].inspect}" unless expected_hash[:progname].nil?
    if expected_hash[:attributes].is_a?(Hash) && !expected_hash[:attributes].empty?
      attributes = Lumberjack::Utils.flatten_attributes(expected_hash[:attributes])
      attributes_info = attributes.collect { |name, value| "#{name}=#{value.inspect}" }.join(", ")
      info << "attributes: #{attributes_info}"
    end
    info.join(", ")
  end
end

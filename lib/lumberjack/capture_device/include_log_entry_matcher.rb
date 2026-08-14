# frozen_string_literal: true

# RSpec matcher for checking captured logs for specific entries.
class Lumberjack::CaptureDevice::IncludeLogEntryMatcher
  # Displayed as the actual value for an expected attribute that the log entry does not have.
  MISSING_VALUE = "(not set)"

  private_constant :MISSING_VALUE

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

    device.include?(@expected_hash)
  end

  # Generate a failure message when the matcher fails.
  #
  # @return [String] A formatted failure message.
  def failure_message
    if valid_logger?
      formatted_failure_message(@expected_hash)
    else
      wrong_object_type_message(@logger)
    end
  end

  # Generate a failure message when the negated matcher fails.
  #
  # @return [String] A formatted failure message for negated expectations.
  def failure_message_when_negated
    if valid_logger?
      formatted_negated_failure_message(@expected_hash)
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

  # Generate a diff between a log entry and the expected log entry values. The severity,
  # message, progname, and attributes of the entry are listed. Values that don't match the
  # expectation are shown on a pair of lines with the expected value prefixed with "-" and
  # the value from the log entry prefixed with "+". This is intended to make it easy to spot
  # exactly which fields kept an entry from matching.
  #
  # The comparison is done by Lumberjack::LogEntryMatcher#diff so the diff always agrees
  # with the result of the match.
  #
  # @param entry [Lumberjack::LogEntry] The log entry to compare to the expectation.
  # @param indent [Integer] The number of spaces to indent each line.
  # @return [String] A formatted diff of the entry and the expectation.
  def entry_diff(entry, indent: 2)
    indent_str = " " * indent

    entry_differences(entry).collect do |name, expected, actual, matched|
      if matched
        "#{indent_str}  #{name}: #{actual}"
      else
        "#{indent_str}- #{name}: #{expected}#{Lumberjack::LINE_SEPARATOR}#{indent_str}+ #{name}: #{actual}"
      end
    end.join(Lumberjack::LINE_SEPARATOR)
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
  # @param expected_hash [Hash] The expected log entry attributes.
  # @return [String] A formatted failure message with context.
  def formatted_failure_message(expected_hash)
    message = +"expected logs to include entry:\n" \
      "#{Lumberjack::Device::Test.formatted_expectation(expected_hash, indent: 2)}"

    closest_match = device.closest_match(**expected_hash)
    if closest_match
      message << "\n\nClosest match found (- expected, + actual):\n" \
        "#{entry_diff(closest_match, indent: 2)}"
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
  # @param expected_hash [Hash] The expected log entry attributes that should not be present.
  # @return [String] A formatted failure message for negated expectations.
  def formatted_negated_failure_message(expected_hash)
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

  # Build the matcher used to compare log entries to the expectation. The entry formatter
  # from the device is used so filter values are matched the same way they are by the
  # device itself.
  #
  # @return [Lumberjack::LogEntryMatcher] The matcher for the expected values.
  def log_entry_matcher
    Lumberjack::LogEntryMatcher.new(
      message: @expected_hash[:message],
      severity: @expected_hash[:severity],
      progname: @expected_hash[:progname],
      attributes: @expected_hash[:attributes],
      formatter: device&.entry_formatter
    )
  end

  # Compare a log entry to the expected values one field at a time. The comparison itself is
  # done by Lumberjack::LogEntryMatcher#diff which reports only the mismatched fields; the
  # rest of the entry is filled in from the entry so it can be seen in full.
  #
  # @param entry [Lumberjack::LogEntry] The log entry to compare to the expectation.
  # @return [Array<Array>] An array of [name, expected value, actual value, matched] tuples
  #   in the order they should be displayed. The values are already formatted for display.
  def entry_differences(entry)
    diff = log_entry_matcher.diff(entry)
    differences = []

    mismatch = diff["severity"]
    differences << if mismatch
      # Severities are already reported as labels by the diff.
      ["severity", mismatch[:expected].to_s, mismatch[:actual].to_s, false]
    else
      ["severity", nil, entry.severity_label, true]
    end

    differences << field_difference("message", diff["message"], entry.message)

    unless diff["progname"].nil? && entry.progname.nil?
      differences << field_difference("progname", diff["progname"], entry.progname)
    end

    differences.concat(attribute_differences(entry, diff["attributes"]))
  end

  # Build the display tuple for a single log entry field.
  #
  # @param name [String] The name of the field.
  # @param mismatch [Hash, nil] The expected and actual values reported by the diff, or nil
  #   if the field matched the expectation.
  # @param value [Object] The value from the log entry, used when the field matched.
  # @return [Array] A [name, expected value, actual value, matched] tuple.
  def field_difference(name, mismatch, value)
    if mismatch
      [name, formatted_value(mismatch[:expected]), formatted_value(mismatch[:actual]), false]
    else
      [name, nil, formatted_value(value), true]
    end
  end

  # Build the display tuples for the attributes of a log entry. Mismatches are reported by
  # the diff per attribute using dot notation names. The remaining attributes on the entry
  # are listed as well, followed by any expected attributes the entry does not have.
  #
  # @param entry [Lumberjack::LogEntry] The log entry being compared to the expectation.
  # @param mismatches [Hash, nil] The attribute mismatches reported by the diff.
  # @return [Array<Array>] An array of [name, expected value, actual value, matched] tuples.
  def attribute_differences(entry, mismatches)
    mismatches ||= {}

    if mismatches.include?(:expected)
      # Matchers like RSpec's hash_including are matched against the attributes hash as a whole.
      return [field_difference("attributes", mismatches, nil)]
    end

    entry_attributes = Lumberjack::Utils.flatten_attributes(entry.attributes || {})

    differences = entry_attributes.collect do |name, value|
      field_difference("attributes.#{name}", mismatches[name], value)
    end

    (mismatches.keys - entry_attributes.keys).each do |name|
      mismatch = mismatches[name]
      actual = mismatch[:actual].nil? ? MISSING_VALUE : formatted_value(mismatch[:actual])
      differences << ["attributes.#{name}", formatted_value(mismatch[:expected]), actual, false]
    end

    differences
  end

  # The Lumberjack::Device::Test the entries are being matched against.
  #
  # @return [Lumberjack::Device::Test, nil] The device, or nil if the logger is not valid.
  def device
    return nil unless valid_logger?

    @logger.is_a?(Lumberjack::Device::Test) ? @logger : @logger.device
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

# frozen_string_literal: true

# RSpec matcher for checking captured logs for specific entries.
class Lumberjack::CaptureDevice::IncludeLogEntryMatcher
  def initialize(expected_hash)
    @expected_hash = expected_hash.transform_keys(&:to_sym)
    @captured_logger = nil
  end

  def matches?(actual)
    @captured_logger = actual
    return false unless valid_captured_logger?

    @captured_logger.include?(@expected_hash)
  end

  def failure_message
    if valid_captured_logger?
      formatted_failure_message(@captured_logger, @expected_hash)
    else
      wrong_object_type_message(@captured_logger)
    end
  end

  def failure_message_when_negated
    if valid_captured_logger?
      formatted_negated_failure_message(@captured_logger, @expected_hash)
    else
      wrong_object_type_message(@captured_logger)
    end
  end

  def description
    "have logged entry with #{expectation_description(@expected_hash)}"
  end

  private

  def valid_captured_logger?
    @captured_logger.is_a?(Lumberjack::CaptureDevice)
  end

  def wrong_object_type_message(captured_logger)
    "Expected a Lumberjack::CaptureDevice object, but received a #{captured_logger.class}."
  end

  def formatted_failure_message(captured_logger, expected_hash)
    message = "expected logs to include entry:\n" \
      "#{Lumberjack::CaptureDevice.formatted_expectation(expected_hash, indent: 2)}\n\n" \
      "Captured #{captured_logger.length} log #{(captured_logger.length == 1) ? "entry" : "entries"}"

    if captured_logger.length > 0
      message << "\n----------------------\n"
      captured_logger.each do |entry|
        message << "#{Lumberjack::CaptureDevice.formatted_entry(entry)}\n"
      end
    end

    closest_match = captured_logger.closest_match(**expected_hash)
    if closest_match
      message = "#{message}\n\nClosest match found:" \
        "#{Lumberjack::CaptureDevice.formatted_expectation(closest_match, indent: 2)}"
    end

    message
  end

  def formatted_negated_failure_message(captured_logger, expected_hash)
    message = "expected logs not to include entry:\n" \
      "#{Lumberjack::CaptureDevice.formatted_expectation(expected_hash, indent: 2)}"

    match = captured_logger.match(**expected_hash)
    if match
      message = "#{message}\n\nFound entry:\n" \
        "#{Lumberjack::CaptureDevice.formatted_expectation(match, indent: 2)}"
    end

    message
  end

  def expectation_description(expected_hash)
    info = []
    info << "level: #{expected_hash[:level].inspect}" unless expected_hash[:level].nil?
    info << "message: #{expected_hash[:message].inspect}" unless expected_hash[:message].nil?
    info << "progname: #{expected_hash[:progname].inspect}" unless expected_hash[:progname].nil?
    if expected_hash[:tags].is_a?(Hash) && !expected_hash[:tags].empty?
      tags = Lumberjack::Utils.flatten_tags(expected_hash[:tags])
      tags_info = tags.collect { |name, value| "#{name}=#{value.inspect}" }.join(", ")
      info << "tags: #{tags_info}"
    end
    info.join(", ")
  end
end

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
      formatted_failure_message(@captured_logger, @expected_hash, negated: false)
    else
      wrong_object_type_message(@captured_logger)
    end
  end

  def failure_message_when_negated
    if valid_captured_logger?
      formatted_failure_message(@captured_logger, @expected_hash, negated: true)
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

  def formatted_failure_message(captured_logger, expected_hash, negated:)
    closest_match = captured_logger.closest_match(**expected_hash)
    message = "expected logs did not include expected entry.\n\n" \
      "Expected entry:\n-----------\n#{Lumberjack::CaptureDevice.formatted_expectation(expected_hash)}\n\n" \
      "Captured logs:\n-----------\n#{captured_logger.inspect}"

    if closest_match
      # Convert the entry to a hash format for formatted_expectation
      closest_match_hash = {
        level: closest_match.severity_label,
        message: closest_match.message,
        progname: closest_match.progname,
        tags: closest_match.tags
      }.compact

      message = "#{message}\n\nClosest match found:\n-----------\n" \
        "#{Lumberjack::CaptureDevice.formatted_expectation(closest_match_hash)}"
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

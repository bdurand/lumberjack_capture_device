# frozen_string_literal: true

require_relative "../../spec_helper"
require_relative "../../../lib/lumberjack/capture_device/rspec"

RSpec.describe Lumberjack::CaptureDevice::IncludeLogEntryMatcher do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, severity: :debug) }
  let(:capture_device) do
    device = Lumberjack::CaptureDevice.new
    logger.device = device
    logger.formatter = Lumberjack::Formatter.empty

    # Add some test entries using the logger
    logger.info("test message")
    logger.error("error message")
    logger.debug("debug message")

    device
  end
  let(:matcher) { described_class.new(severity: :info, message: "test message") }

  describe "#matches?" do
    context "when given a CaptureDevice directly" do
      it "returns true when the expected entry exists" do
        expect(matcher.matches?(capture_device)).to be true
      end

      it "returns false when the expected entry does not exist" do
        non_matching_matcher = described_class.new(severity: :info, message: "non-existent message")
        expect(non_matching_matcher.matches?(capture_device)).to be false
      end
    end

    context "when given an invalid object" do
      it "returns false for non-CaptureDevice objects" do
        expect(matcher.matches?("not a capture device")).to be false
        expect(matcher.matches?([])).to be false
        expect(matcher.matches?(nil)).to be false
      end
    end
  end

  describe "#failure_message" do
    context "when given a valid CaptureDevice" do
      it "returns a formatted message with expected entry and captured logs" do
        non_matching_matcher = described_class.new(severity: :info, message: "non-existent message")
        non_matching_matcher.matches?(capture_device)

        message = non_matching_matcher.failure_message

        expect(message).to include("expected logs to include entry:")
        expect(message).to include("Captured 3 log entries")
        expect(message).to include("non-existent message")
      end

      it "includes closest match information when available" do
        # Create a device with no matching entries
        empty_device = Lumberjack::CaptureDevice.new
        logger.device = empty_device
        logger.info("different message")

        # Mock the closest_match method to return an entry-like object
        entry = Lumberjack::LogEntry.new(
          Time.now,
          Logger::INFO,
          "similar message",
          nil,
          nil,
          nil
        )
        allow(empty_device).to receive(:closest_match).and_return(entry)

        non_matching_matcher = described_class.new(severity: :info, message: "non-existent message")
        non_matching_matcher.matches?(empty_device)

        message = non_matching_matcher.failure_message

        expect(message).to include("Closest match found:")
      end
    end

    context "when given an invalid object" do
      it "returns an error message about wrong object type" do
        matcher.matches?("not a capture device")

        message = matcher.failure_message

        expect(message).to eq("Expected a Lumberjack::CaptureDevice object, but received a String.")
      end
    end
  end

  describe "#failure_message_when_negated" do
    context "when given a valid CaptureDevice" do
      it "returns a formatted message for negated expectations" do
        matcher.matches?(capture_device)

        message = matcher.failure_message_when_negated

        expect(message).to include("expected logs not to include entry:")
        expect(message).to include("Found entry:")
      end
    end

    context "when given an invalid object" do
      it "returns an error message about wrong object type" do
        matcher.matches?("not a capture device")

        message = matcher.failure_message_when_negated

        expect(message).to eq("Expected a Lumberjack::CaptureDevice object, but received a String.")
      end
    end
  end

  describe "#description" do
    it "returns a description of the expectation" do
      matcher = described_class.new(severity: :info, message: "test message", progname: "TestApp")

      description = matcher.description

      expect(description).to eq("have logged entry with severity: :info, message: \"test message\", progname: \"TestApp\"")
    end

    it "handles expectations with tags" do
      matcher = described_class.new(severity: :info, tags: {user_id: 123, action: "login"})

      description = matcher.description

      expect(description).to include("have logged entry with")
      expect(description).to include("severity: :info")
      expect(description).to include("tags:")
      expect(description).to include("user_id=123")
      expect(description).to include("action=\"login\"")
    end

    it "handles minimal expectations" do
      matcher = described_class.new(message: "simple")

      description = matcher.description

      expect(description).to eq("have logged entry with message: \"simple\"")
    end
  end

  describe "private methods" do
    describe "#valid_captured_logger?" do
      it "returns true for CaptureDevice objects" do
        matcher.matches?(capture_device)
        expect(matcher.send(:valid_captured_logger?)).to be true
      end

      it "returns false for non-CaptureDevice objects" do
        matcher.matches?("not a capture device")
        expect(matcher.send(:valid_captured_logger?)).to be false
      end
    end

    describe "#wrong_object_type_message" do
      it "returns a descriptive error message" do
        message = matcher.send(:wrong_object_type_message, "test string")
        expect(message).to eq("Expected a Lumberjack::CaptureDevice object, but received a String.")
      end
    end

    describe "#expectation_description" do
      it "formats a simple expectation" do
        expected_hash = {severity: :info, message: "test"}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info, message: \"test\"")
      end

      it "includes progname when present" do
        expected_hash = {severity: :info, message: "test", progname: "TestApp"}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info, message: \"test\", progname: \"TestApp\"")
      end

      it "formats tags when present" do
        expected_hash = {severity: :info, tags: {user_id: 123, action: "login"}}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to include("severity: :info")
        expect(description).to include("tags: user_id=123, action=\"login\"")
      end

      it "handles empty tags" do
        expected_hash = {severity: :info, tags: {}}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info")
      end

      it "handles nil values by omitting them" do
        expected_hash = {severity: :info, message: nil, progname: nil}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info")
      end
    end
  end

  # Integration tests with the RSpec helper method
  describe "integration with include_log_entry helper" do
    it "works with the RSpec helper method" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("integration test message")
      end

      expect(logs).to include_log_entry(severity: :info, message: "integration test message")
      expect(logs).not_to include_log_entry(severity: :error, message: "integration test message")
    end

    it "provides clear failure messages in real usage" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("actual message")
      end

      expect {
        expect(logs).to include_log_entry(severity: :info, message: "expected message")
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected logs to include entry/)
    end
  end
end

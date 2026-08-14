# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::CaptureDevice::IncludeLogEntryMatcher do
  let(:logger) { Lumberjack::Logger.new(:test) }
  let(:matcher) { Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, message: "test message") }

  before do
    logger.info("test message")
    logger.error("error message")
    logger.debug("debug message")
  end

  describe "#matches?" do
    context "when given a Lumberjack logger directly" do
      it "returns true when the expected entry exists" do
        expect(matcher.matches?(logger)).to be true
      end

      it "returns false when the expected entry does not exist" do
        non_matching_matcher = described_class.new(severity: :info, message: "non-existent message")
        expect(non_matching_matcher.matches?(logger)).to be false
      end
    end

    context "when given an invalid object" do
      it "returns false for non-Lumberjack logger objects" do
        expect(matcher.matches?("not a logger")).to be false
        expect(matcher.matches?([])).to be false
        expect(matcher.matches?(nil)).to be false
      end

      it "returns false for loggers not using a Test device" do
        file_logger = Lumberjack::Logger.new(StringIO.new)
        expect(matcher.matches?(file_logger)).to be false
      end
    end
  end

  describe "#failure_message" do
    context "when given a valid logger" do
      it "returns a formatted message with expected entry and logged logs" do
        non_matching_matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, message: "non-existent message")
        non_matching_matcher.matches?(logger)

        message = non_matching_matcher.failure_message

        expect(message).to include("expected logs to include entry:")
        expect(message).to include("Logged 3 entries")
        expect(message).to include("non-existent message")
      end

      it "includes closest match information when available" do
        # Create a logger with no matching entries
        empty_logger = Lumberjack::Logger.new(:test, severity: :info)
        logger.device = empty_logger.device
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
        allow(empty_logger).to receive(:closest_match).and_return(entry)

        non_matching_matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, message: "non-existent message")
        non_matching_matcher.matches?(empty_logger)

        message = non_matching_matcher.failure_message

        expect(message).to include("Closest match found:")
      end

      it "includes a matcher used as the attributes" do
        logger.info("test message", user_id: 456)

        non_matching_matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(message: "test message", attributes: hash_including(user_id: 123))
        expect(non_matching_matcher.matches?(logger)).to be false

        message = non_matching_matcher.failure_message

        expect(message).to include("attributes: hash_including(user_id: 123)")
      end
    end

    context "when given an invalid object" do
      it "returns an error message about wrong object type" do
        matcher.matches?("not a capture device")

        message = matcher.failure_message

        expect(message).to eq("Expected a Lumberjack::Logger object, but received a String.")
      end
    end
  end

  describe "#failure_message_when_negated" do
    context "when given a valid Lumberjack logger" do
      it "returns a formatted message for negated expectations" do
        matcher.matches?(logger)

        message = matcher.failure_message_when_negated

        expect(message).to include("expected logs not to include entry:")
        expect(message).to include("Found entry:")
      end
    end

    context "when given an invalid object" do
      it "returns an error message about wrong object type" do
        matcher.matches?("not a capture device")

        message = matcher.failure_message_when_negated

        expect(message).to eq("Expected a Lumberjack::Logger object, but received a String.")
      end
    end
  end

  describe "#description" do
    it "returns a description of the expectation" do
      matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, message: "test message", progname: "TestApp")

      description = matcher.description

      expect(description).to eq("have logged entry with severity: :info, message: \"test message\", progname: \"TestApp\"")
    end

    it "handles expectations with attributes" do
      matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, attributes: {user_id: 123, action: "login"})

      description = matcher.description

      expect(description).to include("have logged entry with")
      expect(description).to include("severity: :info")
      expect(description).to include("attributes:")
      expect(description).to include("user_id=123")
      expect(description).to include("action=\"login\"")
    end

    it "handles minimal expectations" do
      matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(message: "simple")

      description = matcher.description

      expect(description).to eq("have logged entry with message: \"simple\"")
    end

    it "handles a matcher as the attributes" do
      matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, attributes: hash_including(user_id: 123))

      description = matcher.description

      expect(description).to eq("have logged entry with severity: :info, attributes: hash_including(user_id: 123)")
    end
  end

  describe "private methods" do
    describe "#valid_captured_logger?" do
      it "returns true for Lumberjack::Logger objects" do
        matcher.matches?(logger)
        expect(matcher.send(:valid_logger?)).to be true
      end

      it "returns false for non-Lumberjack logger objects" do
        matcher.matches?("not a logger")
        expect(matcher.send(:valid_logger?)).to be false
      end
    end

    describe "#wrong_object_type_message" do
      it "returns a descriptive error message" do
        message = matcher.send(:wrong_object_type_message, "test string")
        expect(message).to eq("Expected a Lumberjack::Logger object, but received a String.")
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

      it "formats attributes when present" do
        expected_hash = {severity: :info, attributes: {user_id: 123, action: "login"}}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to include("severity: :info")
        expect(description).to include("attributes: user_id=123, action=\"login\"")
      end

      it "handles empty attributes" do
        expected_hash = {severity: :info, attributes: {}}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info")
      end

      it "formats a matcher used as the attributes" do
        expected_hash = {severity: :info, attributes: hash_including("user.id" => 123)}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("severity: :info, attributes: hash_including(\"user.id\" => 123)")
      end

      it "formats matchers used as attribute values" do
        expected_hash = {attributes: {user_id: instance_of(Integer)}}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("attributes: user_id=an_instance_of(Integer)")
      end

      it "formats matchers used as the message" do
        expected_hash = {message: a_string_including("test")}
        description = matcher.send(:expectation_description, expected_hash)
        expect(description).to eq("message: a string including \"test\"")
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
      logger.info("integration test message")
      expect(logger).to include_log_entry(severity: :info, message: "integration test message")
      expect(logger).not_to include_log_entry(severity: :error, message: "integration test message")
    end

    it "provides clear failure messages in real usage" do
      logger.info("actual message")
      expect {
        expect(logger).to include_log_entry(severity: :info, message: "expected message")
      }.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected logs to include entry/)
    end
  end
end

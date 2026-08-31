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
        other_logger = Lumberjack::Logger.new(:test, severity: :info)
        other_logger.info("different message")

        non_matching_matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(severity: :info, message: "non-existent message")
        non_matching_matcher.matches?(other_logger)

        message = non_matching_matcher.failure_message

        expect(message).to include("Closest match found (- expected, + actual):")
        expect(message).to include("    severity: INFO")
        expect(message).to include("  - message: \"non-existent message\"")
        expect(message).to include("  + message: \"different message\"")
      end

      it "includes a matcher used as the attributes" do
        logger.info("test message", user_id: 456)

        non_matching_matcher = Lumberjack::CaptureDevice::IncludeLogEntryMatcher.new(message: "test message", attributes: hash_including(user_id: 123))
        expect(non_matching_matcher.matches?(logger)).to be false

        message = non_matching_matcher.failure_message

        expect(message).to include("attributes: hash_including(#{inspect_hash_contents({user_id: 123})})")
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

      expect(description).to eq("have logged entry with severity: :info, attributes: hash_including(#{inspect_hash_contents({user_id: 123})})")
    end
  end

  describe "#entry_diff" do
    let(:entry) do
      Lumberjack::LogEntry.new(
        Time.now,
        Logger::INFO,
        "User logged out",
        "web",
        nil,
        {user: {id: 456, role: "guest"}, duration: 1.5}
      )
    end

    it "shows the expected and actual values for fields that do not match" do
      matcher = described_class.new(severity: :warn, message: "User logged in", progname: "worker")

      expect(matcher.entry_diff(entry)).to eq([
        "  - severity: WARN",
        "  + severity: INFO",
        "  - message: \"User logged in\"",
        "  + message: \"User logged out\"",
        "  - progname: \"worker\"",
        "  + progname: \"web\"",
        "    attributes.user.id: 456",
        "    attributes.user.role: \"guest\"",
        "    attributes.duration: 1.5"
      ].join("\n"))
    end

    it "shows a single line with the entry value for fields that match" do
      matcher = described_class.new(severity: :info, message: /logged/)

      expect(matcher.entry_diff(entry)).to eq([
        "    severity: INFO",
        "    message: \"User logged out\"",
        "    progname: \"web\"",
        "    attributes.user.id: 456",
        "    attributes.user.role: \"guest\"",
        "    attributes.duration: 1.5"
      ].join("\n"))
    end

    it "compares nested attributes individually and flags ones the entry does not have" do
      matcher = described_class.new(attributes: {user: {id: 456, role: "admin"}, request_id: "abc"})

      diff = matcher.entry_diff(entry)

      expect(diff).to include("    attributes.user.id: 456")
      expect(diff).to include("  - attributes.user.role: \"admin\"\n  + attributes.user.role: \"guest\"")
      expect(diff).to include("  - attributes.request_id: \"abc\"\n  + attributes.request_id: (not set)")
    end

    it "compares a matcher against the attributes as a whole" do
      matcher = described_class.new(attributes: hash_including(user_id: 1))

      diff = matcher.entry_diff(entry)

      expect(diff).to include("  - attributes: hash_including(#{inspect_hash_contents({user_id: 1})})")
      expect(diff).to include("  + attributes: #{inspect_hash({"user" => {"id" => 456, "role" => "guest"}, "duration" => 1.5})}")
      expect(diff).to_not include("attributes.user.id")
    end

    it "uses matcher descriptions for expected values" do
      matcher = described_class.new(message: a_string_including("logged in"), attributes: {duration: instance_of(Integer)})

      diff = matcher.entry_diff(entry)

      expect(diff).to include("  - message: a string including \"logged in\"")
      expect(diff).to include("  - attributes.duration: an_instance_of(Integer)\n  + attributes.duration: 1.5")
    end

    it "omits the progname when neither the expectation nor the entry has one" do
      entry_without_progname = Lumberjack::LogEntry.new(Time.now, Logger::INFO, "message", nil, nil, nil)
      matcher = described_class.new(message: "message")

      expect(matcher.entry_diff(entry_without_progname)).to eq([
        "    severity: INFO",
        "    message: \"message\""
      ].join("\n"))
    end

    context "with an entry formatter on the device" do
      let(:entry_formatter) do
        Lumberjack::EntryFormatter.build do |config|
          config.format_attributes(Exception) { |e| {kind: e.class.name, message: e.message} }
        end
      end

      let(:error) do
        raise "boom"
      rescue => e
        e
      end

      let(:formatted_logger) do
        logger = Lumberjack::Logger.new(Lumberjack::CaptureDevice.new, formatter: entry_formatter)
        logger.device.entry_formatter = logger.formatter
        logger
      end

      it "formats expected values the same way the device does when matching" do
        formatted_logger.error("failed", error: error)
        matcher = described_class.new(attributes: {error: error})

        expect(matcher.matches?(formatted_logger)).to be true
        expect(matcher.entry_diff(formatted_logger.device.last_entry)).to_not match(/^\s+- /)
      end

      it "shows the formatted expected value when a formatted attribute does not match" do
        formatted_logger.error("failed", error: error)
        other_error = ArgumentError.new("bad argument")
        matcher = described_class.new(attributes: {error: other_error})

        expect(matcher.matches?(formatted_logger)).to be false
        diff = matcher.entry_diff(formatted_logger.device.last_entry)

        expect(diff).to include("  - attributes.error.kind: \"ArgumentError\"\n  + attributes.error.kind: \"RuntimeError\"")
        expect(diff).to include("  - attributes.error.message: \"bad argument\"\n  + attributes.error.message: \"boom\"")
      end
    end

    it "indents the diff by the requested amount" do
      matcher = described_class.new(message: "User logged in")

      expect(matcher.entry_diff(entry, indent: 4)).to include("    - message: \"User logged in\"")
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
        expect(description).to eq("severity: :info, attributes: hash_including(#{inspect_hash_contents({"user.id" => 123})})")
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

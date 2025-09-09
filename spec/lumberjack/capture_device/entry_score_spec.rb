# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe Lumberjack::CaptureDevice::EntryScore do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, severity: :debug) }

  # Create real log entries using the capture device
  let(:entries) do
    device = Lumberjack::CaptureDevice.capture(logger) do
      logger.info("User logged in successfully")
      logger.warn("Database connection slow")
      logger.error("Failed to authenticate user")
      logger.debug("Processing request", user_id: 123, action: "login")
      logger.progname = "TestApp"
      logger.info("Service started", service: "test")
    end
    device.entries
  end

  let(:entry_info) { entries[0] }      # "User logged in successfully"
  let(:entry_warn) { entries[1] }      # "Database connection slow"
  let(:entry_error) { entries[2] }     # "Failed to authenticate user"
  let(:entry_debug) { entries[3] }     # "Processing request" with attributes
  let(:entry_with_progname) { entries[4] } # "Service started" with progname

  describe ".calculate_match_score" do
    it "returns 1.0 for perfect matches" do
      score = described_class.calculate_match_score(
        entry_info,
        "User logged in successfully",
        Logger::INFO,
        {},
        nil
      )
      expect(score).to eq 1.0
    end

    it "returns 0.0 when no criteria are provided" do
      score = described_class.calculate_match_score(entry_info, nil, nil, nil, nil)
      expect(score).to eq 0.0
    end

    it "returns partial scores for partial matches" do
      score = described_class.calculate_match_score(
        entry_info,
        "User logged in successfully",
        Logger::WARN, # Different severity
        nil,
        nil
      )
      expect(score).to be > 0.5
      expect(score).to be < 1.0
    end

    it "considers severity proximity for nearby severitys" do
      exact_score = described_class.calculate_match_score(
        entry_info,
        nil,
        Logger::INFO,
        nil,
        nil
      )

      nearby_score = described_class.calculate_match_score(
        entry_info,
        nil,
        Logger::WARN, # One severity away
        nil,
        nil
      )

      distant_score = described_class.calculate_match_score(
        entry_info,
        nil,
        Logger::FATAL, # Far away
        nil,
        nil
      )

      expect(exact_score).to be > nearby_score
      expect(nearby_score).to be > distant_score
    end

    it "scores entries below minimum threshold as 0" do
      score = described_class.calculate_match_score(
        entry_info,
        "completely different message",
        Logger::FATAL,
        {different: "attributes"},
        "DifferentApp"
      )
      expect(score).to be < described_class::MIN_SCORE_THRESHOLD
    end

    it "handles attribute matching" do
      score = described_class.calculate_match_score(
        entry_debug,
        nil,
        nil,
        {user_id: 123},
        nil
      )
      expect(score).to be > 0.0
    end

    it "handles progname matching" do
      score = described_class.calculate_match_score(
        entry_with_progname,
        nil,
        nil,
        nil,
        "TestApp"
      )
      expect(score).to be > 0.0
    end
  end

  describe ".calculate_field_score" do
    context "with string filters" do
      it "returns 1.0 for exact matches" do
        score = described_class.calculate_field_score("test message", "test message")
        expect(score).to eq 1.0
      end

      it "returns 0.7 for substring matches" do
        score = described_class.calculate_field_score("test message", "test")
        expect(score).to eq 0.7
      end

      it "returns similarity score for partial matches" do
        score = described_class.calculate_field_score("test message", "test mesage") # typo
        expect(score).to be > 0.0
        expect(score).to be < 0.7
      end

      it "returns 0.0 for completely different strings" do
        score = described_class.calculate_field_score("test message", "xyz")
        expect(score).to eq 0.0
      end
    end

    context "with regex filters" do
      it "returns 1.0 for matching regex" do
        score = described_class.calculate_field_score("test message", /test/)
        expect(score).to eq 1.0
      end

      it "returns 0.0 for non-matching regex" do
        score = described_class.calculate_field_score("test message", /xyz/)
        expect(score).to eq 0.0
      end
    end

    context "with other matchers" do
      it "returns 1.0 when matcher returns true" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_return(true)
        score = described_class.calculate_field_score("test", matcher)
        expect(score).to eq 1.0
      end

      it "returns 0.0 when matcher returns false" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_return(false)
        score = described_class.calculate_field_score("test", matcher)
        expect(score).to eq 0.0
      end

      it "returns 0.0 when matcher raises an exception" do
        matcher = double("matcher")
        allow(matcher).to receive(:===).with("test").and_raise(StandardError)
        score = described_class.calculate_field_score("test", matcher)
        expect(score).to eq 0.0
      end
    end

    context "with nil values" do
      it "returns 0.0 when value is nil" do
        score = described_class.calculate_field_score(nil, "test")
        expect(score).to eq 0.0
      end

      it "returns 0.0 when filter is nil" do
        score = described_class.calculate_field_score("test", nil)
        expect(score).to eq 0.0
      end

      it "returns 0.0 when both are nil" do
        score = described_class.calculate_field_score(nil, nil)
        expect(score).to eq 0.0
      end
    end
  end

  describe ".severity_proximity_score" do
    it "returns 1.0 for exact severity match" do
      score = described_class.severity_proximity_score(
        Logger::INFO,
        Logger::INFO
      )
      expect(score).to eq 1.0
    end

    it "returns 0.7 for one severity difference" do
      score = described_class.severity_proximity_score(
        Logger::INFO,
        Logger::WARN
      )
      expect(score).to eq 0.7
    end

    it "returns 0.4 for two severity difference" do
      score = described_class.severity_proximity_score(
        Logger::DEBUG,
        Logger::WARN
      )
      expect(score).to eq 0.4
    end

    it "returns 0.0 for three or more severity difference" do
      score = described_class.severity_proximity_score(
        Logger::DEBUG,
        Logger::FATAL
      )
      expect(score).to eq 0.0
    end
  end

  describe ".calculate_attributes_score" do
    let(:entry_attributes) { {user_id: 123, action: "login", metadata: {ip: "192.168.1.1"}} }

    it "returns 1.0 for exact attribute matches" do
      score = described_class.calculate_attributes_score(entry_attributes, {user_id: 123})
      expect(score).to eq 1.0
    end

    it "returns partial score for partially matching attributes" do
      score = described_class.calculate_attributes_score(
        entry_attributes,
        {user_id: 123, action: "logout"} # One matches, one doesn't
      )
      expect(score).to eq 0.5
    end

    it "returns 0.0 for completely non-matching attributes" do
      score = described_class.calculate_attributes_score(
        entry_attributes,
        {different_attribute: "value"}
      )
      expect(score).to eq 0.0
    end

    it "handles nested attribute matching" do
      score = described_class.calculate_attributes_score(
        entry_attributes,
        {metadata: {ip: "192.168.1.1"}}
      )
      expect(score).to eq 1.0
    end

    it "returns 0.0 when entry_attributes is nil" do
      score = described_class.calculate_attributes_score(nil, {user_id: 123})
      expect(score).to eq 0.0
    end

    it "returns 0.0 when attributes_filter is not a hash" do
      score = described_class.calculate_attributes_score(entry_attributes, "not a hash")
      expect(score).to eq 0.0
    end
  end
end

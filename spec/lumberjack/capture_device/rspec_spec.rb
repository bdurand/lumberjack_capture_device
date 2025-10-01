# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rspec matchers" do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, severity: :debug) }

  describe "capture_logger" do
    it "capatures log entries from a block" do
      logs = capture_logger(logger) do
        logger.info("test message")
      end

      expect(logs).to include_log_entry(severity: :info, message: "test message")
    end

    it "captures entries within a block" do
      capture_logger(logger) do |logs|
        logger.info("test message")
        expect(logs).to include_log_entry(severity: :info, message: "test message")
      end
    end

    it "handles invalid objects gracefully" do
      expect {
        capture_logger("not a logger") { true }
      }.to raise_error(ArgumentError) do |error|
        expect(error.message).to include("Expected a Logger, but received a String")
      end
    end
  end
end

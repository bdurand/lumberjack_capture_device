# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe "rspec matchers" do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, severity: :debug) }

  describe "include_log_entry matcher" do
    describe "when applied to a captured logger" do
      it "matches when the expected log entry exists" do
        logs = capture_logger(logger) do
          logger.info("test message")
          logger.error("error occurred")
        end

        expect(logs).to include_log_entry(severity: :info, message: "test message")
        expect(logs).to include_log_entry(severity: :error, message: "error occurred")
      end

      it "does not match when the expected log entry does not exist" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect(logs).not_to include_log_entry(severity: :error, message: "test message")
        expect(logs).not_to include_log_entry(severity: :info, message: "different message")
      end

      it "matches with partial criteria" do
        logs = capture_logger(logger) do
          logger.warn("warning message", user_id: 123, action: "login")
        end

        expect(logs).to include_log_entry(severity: :warn)
        expect(logs).to include_log_entry(message: "warning message")
        expect(logs).to include_log_entry(message: /warning/)
        expect(logs).to include_log_entry(attributes: {user_id: 123})
        expect(logs).to include_log_entry(attributes: {action: "login"})
      end

      it "matches with regular expressions" do
        logs = capture_logger(logger) do
          logger.info("User 123 logged in successfully")
        end

        expect(logs).to include_log_entry(severity: :info, message: /User \d+ logged in/)
        expect(logs).not_to include_log_entry(severity: :info, message: /User \d+ logged out/)
      end

      it "matches with complex attribute structures" do
        logs = capture_logger(logger) do
          logger.info("complex log",
            user: {id: 123, name: "John"},
            metadata: {version: "1.0", features: ["auth", "logging"]})
        end

        expect(logs).to include_log_entry(attributes: {user: {id: 123}})
        expect(logs).to include_log_entry(attributes: {"user.id" => 123})
        expect(logs).to include_log_entry(attributes: {metadata: {version: "1.0"}})
        expect(logs).not_to include_log_entry(attributes: {user: {id: 456}})
      end

      it "matches with progname" do
        logs = capture_logger(logger) do
          logger.progname = "TestApp"
          logger.info("application started")
        end

        expect(logs).to include_log_entry(severity: :info, progname: "TestApp")
        expect(logs).to include_log_entry(progname: /Test/)
        expect(logs).not_to include_log_entry(progname: "DifferentApp")
      end

      it "provides clear failure messages" do
        logs = capture_logger(logger) do
          logger.info("actual message")
        end

        expect {
          expect(logs).to include_log_entry(severity: :info, message: "expected message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("expected logs to include entry")
          expect(error.message).to include("expected message")
          expect(error.message).to include("Logged 1 entry")
          expect(error.message).to include("actual message")
        end
      end

      it "provides clear failure messages for negated expectations" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect {
          expect(logs).not_to include_log_entry(severity: :info, message: "test message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "when applied to a plain Lumberjack::Device::Test device" do
      let(:logger) { Lumberjack::Logger.new(:test, level: :debug) }

      it "matches log entries" do
        logger.info("test message", user_id: 123)

        expect(logger).to include_log_entry(severity: :info, message: "test message", attributes: {user_id: 123})
        expect(logger).not_to include_log_entry(severity: :error, message: "test message")
      end
    end

    describe "failure message formatting" do
      it "puts the closest match on its own lines" do
        logs = capture_logger(logger) do
          logger.info("almost the message you want")
        end

        matcher = include_log_entry(message: "almost the message you wan")
        matcher.matches?(logs)
        expect(matcher.failure_message).to include("Closest match found (- expected, + actual):\n    severity: INFO")
      end
    end

    describe "edge cases and error handling" do
      it "handles invalid objects gracefully" do
        expect {
          expect("not a logger").to include_log_entry(severity: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::Logger object, but received a String")
        end
      end

      it "handles nil logger gracefully" do
        expect {
          expect(nil).to include_log_entry(severity: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::Logger object, but received a NilClass")
        end
      end

      it "works with matchers in expectation values" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect(logs).to include_log_entry(severity: :info, message: instance_of(String))
        expect(logs).to include_log_entry(severity: :info, message: a_string_matching(/test/))
        expect(logs).not_to include_log_entry(severity: :info, message: instance_of(Integer))
      end
    end

    describe "integration with RSpec features" do
      it "works with let statements" do
        logs = capture_logger(logger) do
          logger.info("from let statement")
        end

        expect(logs).to include_log_entry(message: "from let statement")
      end

      it "works with before hooks" do
        captured_logs = nil

        before_hook = proc do
          captured_logs = capture_logger(logger) do
            logger.info("from before hook")
          end
        end

        before_hook.call
        expect(captured_logs).to include_log_entry(message: "from before hook")
      end

      it "provides proper description for test documentation" do
        matcher = include_log_entry(severity: :info, message: "test")
        expect(matcher.description).to eq("have logged entry with severity: :info, message: \"test\"")
      end
    end
  end

  describe "capture_logger_around_example" do
    let(:underlying_device) { Lumberjack::Device::Test.new }
    let(:logger) { Lumberjack::Logger.new(underlying_device, level: :info) }

    # Models the RSpec::Core::Example::Procsy object yielded to around hooks.
    def fake_example(exception: nil)
      double(
        "example",
        exception: exception,
        location: "./spec/some_spec.rb:12",
        metadata: {description: "does something"}
      ).tap do |example|
        allow(example).to receive(:run) { logger.info("logged inside example") }
      end
    end

    it "does not write captured entries when the example passes" do
      capture_logger_around_example(logger, fake_example)

      expect(underlying_device.entries).to be_empty
    end

    it "writes captured entries with rspec attributes when the example fails" do
      capture_logger_around_example(logger, fake_example(exception: StandardError.new("boom")))

      expect(underlying_device).to include(
        message: "logged inside example",
        attributes: {
          "rspec.location" => "./spec/some_spec.rb:12",
          "rspec.description" => "does something"
        }
      )
    end
  end
end

# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe "rspec matchers" do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, level: :debug) }

  describe "include_log_entry matcher" do
    describe "when applied to a captured logger" do
      it "matches when the expected log entry exists" do
        logs = capture_logger(logger) do
          logger.info("test message")
          logger.error("error occurred")
        end

        expect(logs).to include_log_entry(level: :info, message: "test message")
        expect(logs).to include_log_entry(level: :error, message: "error occurred")
      end

      it "does not match when the expected log entry does not exist" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect(logs).not_to include_log_entry(level: :error, message: "test message")
        expect(logs).not_to include_log_entry(level: :info, message: "different message")
      end

      it "matches with partial criteria" do
        logs = capture_logger(logger) do
          logger.warn("warning message", user_id: 123, action: "login")
        end

        expect(logs).to include_log_entry(level: :warn)
        expect(logs).to include_log_entry(message: "warning message")
        expect(logs).to include_log_entry(message: /warning/)
        expect(logs).to include_log_entry(tags: {user_id: 123})
        expect(logs).to include_log_entry(tags: {action: "login"})
      end

      it "matches with regular expressions" do
        logs = capture_logger(logger) do
          logger.info("User 123 logged in successfully")
        end

        expect(logs).to include_log_entry(level: :info, message: /User \d+ logged in/)
        expect(logs).not_to include_log_entry(level: :info, message: /User \d+ logged out/)
      end

      it "matches with complex tag structures" do
        logs = capture_logger(logger) do
          logger.info("complex log",
            user: {id: 123, name: "John"},
            metadata: {version: "1.0", features: ["auth", "logging"]})
        end

        expect(logs).to include_log_entry(tags: {user: {id: 123}})
        expect(logs).to include_log_entry(tags: {"user.id" => 123})
        expect(logs).to include_log_entry(tags: {metadata: {version: "1.0"}})
        expect(logs).not_to include_log_entry(tags: {user: {id: 456}})
      end

      it "matches with progname" do
        logs = capture_logger(logger) do
          logger.progname = "TestApp"
          logger.info("application started")
        end

        expect(logs).to include_log_entry(level: :info, progname: "TestApp")
        expect(logs).to include_log_entry(progname: /Test/)
        expect(logs).not_to include_log_entry(progname: "DifferentApp")
      end

      it "provides clear failure messages" do
        logs = capture_logger(logger) do
          logger.info("actual message")
        end

        expect {
          expect(logs).to include_log_entry(level: :info, message: "expected message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("expected logs to include entry")
          expect(error.message).to include("expected message")
          expect(error.message).to include("Captured 1 log entry")
          expect(error.message).to include("actual message")
        end
      end

      it "provides clear failure messages for negated expectations" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect {
          expect(logs).not_to include_log_entry(level: :info, message: "test message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "edge cases and error handling" do
      it "handles invalid objects gracefully" do
        expect {
          expect("not a logger").to include_log_entry(level: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::CaptureDevice object, but received a String")
        end
      end

      it "handles nil logger gracefully" do
        expect {
          expect(nil).to include_log_entry(level: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::CaptureDevice object, but received a NilClass")
        end
      end

      it "works with matchers in expectation values" do
        logs = capture_logger(logger) do
          logger.info("test message")
        end

        expect(logs).to include_log_entry(level: :info, message: instance_of(String))
        expect(logs).to include_log_entry(level: :info, message: a_string_matching(/test/))
        expect(logs).not_to include_log_entry(level: :info, message: instance_of(Integer))
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
        matcher = include_log_entry(level: :info, message: "test")
        expect(matcher.description).to eq("have logged entry with level: :info, message: \"test\"")
      end
    end
  end
end

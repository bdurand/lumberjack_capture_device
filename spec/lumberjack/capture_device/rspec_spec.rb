# frozen_string_literal: true

require_relative "../../spec_helper"

RSpec.describe "rspec matchers" do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, level: :debug) }

  describe "have_logged matcher" do
    describe "when applied to a captured logger" do
      it "matches when the expected log entry exists" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("test message")
          logger.error("error occurred")
        end

        expect(logs).to have_logged(level: :info, message: "test message")
        expect(logs).to have_logged(level: :error, message: "error occurred")
      end

      it "does not match when the expected log entry does not exist" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("test message")
        end

        expect(logs).not_to have_logged(level: :error, message: "test message")
        expect(logs).not_to have_logged(level: :info, message: "different message")
      end

      it "matches with partial criteria" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.warn("warning message", user_id: 123, action: "login")
        end

        expect(logs).to have_logged(level: :warn)
        expect(logs).to have_logged(message: "warning message")
        expect(logs).to have_logged(message: /warning/)
        expect(logs).to have_logged(tags: {user_id: 123})
        expect(logs).to have_logged(tags: {action: "login"})
      end

      it "matches with regular expressions" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("User 123 logged in successfully")
        end

        expect(logs).to have_logged(level: :info, message: /User \d+ logged in/)
        expect(logs).not_to have_logged(level: :info, message: /User \d+ logged out/)
      end

      it "matches with complex tag structures" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("complex log",
            user: {id: 123, name: "John"},
            metadata: {version: "1.0", features: ["auth", "logging"]})
        end

        expect(logs).to have_logged(tags: {user: {id: 123}})
        expect(logs).to have_logged(tags: {"user.id" => 123})
        expect(logs).to have_logged(tags: {metadata: {version: "1.0"}})
        expect(logs).not_to have_logged(tags: {user: {id: 456}})
      end

      it "matches with progname" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.progname = "TestApp"
          logger.info("application started")
        end

        expect(logs).to have_logged(level: :info, progname: "TestApp")
        expect(logs).to have_logged(progname: /Test/)
        expect(logs).not_to have_logged(progname: "DifferentApp")
      end

      it "provides clear failure messages" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("actual message")
        end

        expect {
          expect(logs).to have_logged(level: :info, message: "expected message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("expected logs did not include expected entry")
          expect(error.message).to include("Expected entry:")
          expect(error.message).to include("expected message")
          expect(error.message).to include("Captured logs:")
          expect(error.message).to include("actual message")
        end
      end

      it "provides clear failure messages for negated expectations" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("test message")
        end

        expect {
          expect(logs).not_to have_logged(level: :info, message: "test message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    describe "when applied to a block" do
      it "matches when the block logs the expected entry" do
        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.info("test message")
          end
        }.to have_logged(level: :info, message: "test message")
      end

      it "does not match when the block does not log the expected entry" do
        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.info("different message")
          end
        }.not_to have_logged(level: :info, message: "test message")
      end

      it "matches with multiple log entries in block" do
        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.debug("debug info")
            logger.info("important message")
            logger.warn("warning message")
          end
        }.to have_logged(level: :info, message: "important message")

        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.debug("debug info")
            logger.info("important message")
            logger.warn("warning message")
          end
        }.to have_logged(level: :warn, message: "warning message")
      end

      it "matches with tags in block expectations" do
        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.info("user action", user_id: 123, action: "create")
          end
        }.to have_logged(level: :info, tags: {user_id: 123})
      end

      it "works with nested capture blocks" do
        outer_logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("outer message")

          expect {
            Lumberjack::CaptureDevice.capture(logger) do
              logger.debug("inner message")
            end
          }.to have_logged(level: :debug, message: "inner message")

          logger.warn("outer warning")
        end

        expect(outer_logs).to have_logged(level: :info, message: "outer message")
        expect(outer_logs).to have_logged(level: :warn, message: "outer warning")
        # The inner message should not be in the outer logs
        expect(outer_logs).not_to have_logged(level: :debug, message: "inner message")
      end

      it "provides clear failure messages for block expectations" do
        expect {
          expect {
            Lumberjack::CaptureDevice.capture(logger) do
              logger.info("actual message")
            end
          }.to have_logged(level: :info, message: "expected message")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("expected logs did not include expected entry")
          expect(error.message).to include("expected message")
          expect(error.message).to include("actual message")
        end
      end

      it "handles empty blocks" do
        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            # No logging
          end
        }.not_to have_logged(level: :info, message: "any message")
      end

      it "handles blocks with conditional logging" do
        condition = true

        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.info("conditional message") if condition
          end
        }.to have_logged(level: :info, message: "conditional message")

        condition = false

        expect {
          Lumberjack::CaptureDevice.capture(logger) do
            logger.info("conditional message") if condition
          end
        }.not_to have_logged(level: :info, message: "conditional message")
      end
    end

    describe "edge cases and error handling" do
      it "handles invalid objects gracefully" do
        expect {
          expect("not a logger").to have_logged(level: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::CaptureDevice object, but received a String")
        end
      end

      it "handles nil logger gracefully" do
        expect {
          expect(nil).to have_logged(level: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::CaptureDevice object, but received a NilClass")
        end
      end

      it "handles blocks that return non-CaptureDevice objects" do
        expect {
          expect { "not a capture device" }.to have_logged(level: :info, message: "test")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError) do |error|
          expect(error.message).to include("Expected a Lumberjack::CaptureDevice object, but received a String")
        end
      end

      it "works with matchers in expectation values" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("test message")
        end

        expect(logs).to have_logged(level: :info, message: instance_of(String))
        expect(logs).to have_logged(level: :info, message: a_string_matching(/test/))
        expect(logs).not_to have_logged(level: :info, message: instance_of(Integer))
      end
    end

    describe "integration with RSpec features" do
      it "works with let statements" do
        logs = Lumberjack::CaptureDevice.capture(logger) do
          logger.info("from let statement")
        end

        expect(logs).to have_logged(message: "from let statement")
      end

      it "works with before hooks" do
        captured_logs = nil

        before_hook = proc do
          captured_logs = Lumberjack::CaptureDevice.capture(logger) do
            logger.info("from before hook")
          end
        end

        before_hook.call
        expect(captured_logs).to have_logged(message: "from before hook")
      end

      it "provides proper description for test documentation" do
        matcher = have_logged(level: :info, message: "test")
        expect(matcher.description).to eq("have logged entry with level: :info, message: \"test\"")
      end

      it "supports block expectations flag" do
        matcher = have_logged(level: :info, message: "test")
        expect(matcher.supports_block_expectations?).to be true
      end
    end
  end
end

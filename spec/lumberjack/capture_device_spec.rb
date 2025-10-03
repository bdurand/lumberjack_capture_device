# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lumberjack::CaptureDevice do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, level: :info) }

  describe "VERSION" do
    it "has a version number" do
      expect(Lumberjack::CaptureDevice::VERSION).not_to be nil
    end
  end

  describe ".capture" do
    it "should capture log entries inside a block to a buffer" do
      buffer = nil
      device = Lumberjack::CaptureDevice.capture(logger) do |logs|
        logger.debug("one")
        expect(logs.entries.collect(&:message)).to eq ["one"]
        logger.debug("two")
        expect(logs.entries.collect(&:message)).to eq ["one", "two"]
        buffer = logs.entries
      end

      logger.info("foo")
      expect(device.entries).to eq buffer

      device.clear
      expect(device.entries).to eq []

      expect(logger.level).to eq Logger::INFO
    end
  end

  describe "#include?" do
    it "should match the log severity with the deprecated level option", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar")
      end
      expect(logs).to include(level: :info)
    end

    it "should match attributes with the deprecated tags option", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully", user_id: 123)
      end
      result = logs.extract(tags: {user_id: 123})
      expect(result.first.message).to_not be_nil
      expect(result.first.message).to eq "User logged in successfully"
      expect(result.first.attributes["user_id"]).to eq 123
    end
  end

  describe "#extract" do
    it "should extract entries from the buffer", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22], three: nil})
        logger.warn("FOOBAR", foo: "bum")
        logger.with_progname("TestProgname") do
          logger.info("baxbar", foo: "bar")
        end
      end
      expect(logs.extract(message: /foobar/i).collect(&:message)).to eq ["foobar", "FOOBAR"]
      expect(logs.extract(message: /foobar/i, limit: 1).collect(&:message)).to eq ["foobar"]
      expect(logs.extract(severity: :info).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(attributes: {foo: "bar"}).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(progname: "TestProgname").collect(&:message)).to eq ["baxbar"]

      # Deprecated aliases
      expect(logs.extract(level: :info).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(tags: {foo: "bar"}).collect(&:message)).to eq ["foobar", "baxbar"]
    end

    it "can use tags as an alias for attributes", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully", user_id: 123)
      end
      result = logs.extract(tags: {user_id: 123})
      expect(result.first.message).to_not be_nil
      expect(result.first.message).to eq "User logged in successfully"
      expect(result.first.attributes["user_id"]).to eq 123
    end

    it "can use level as an alias for attributes", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully")
      end
      result = logs.extract(level: :info)
      expect(result.first.message).to_not be_nil
      expect(result.first.message).to eq "User logged in successfully"
    end
  end

  describe "#inspect" do
    it "should return a string representation of the captured entries" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar")
        logger.progname = "TestProgname"
        logger.warn("something happened", foo: {bar: "baz", bip: "bop"}, duration: 1.23)
      end
      expect(logs.inspect).to include "<#Lumberjack::CaptureDevice 2 entries captured:"
      expect(logs.inspect).to include "INFO  foobar"
      expect(logs.inspect).to include "WARN  something happened"
      expect(logs.inspect).to include "foo: bar"
      expect(logs.inspect).to include "duration: 1.23"
      expect(logs.inspect).to include "foo.bar: baz"
      expect(logs.inspect).to include "progname: TestProgname"
    end
  end

  describe "#match" do
    it "can use level as an alias for severity", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully")
      end
      result = logs.match(level: :info, message: "User logged in successfully")
      expect(result).to_not be_nil
      expect(result.message).to eq "User logged in successfully"
      expect(result.severity).to eq Logger::INFO
    end

    it "can use tags as an alias for attributes", deprecation_mode: :silent do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully", user_id: 123)
      end
      result = logs.match(tags: {user_id: 123})
      expect(result).to_not be_nil
      expect(result.message).to eq "User logged in successfully"
      expect(result.attributes["user_id"]).to eq 123
    end
  end

  describe "#closest_match" do
    let(:logs) do
      Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully")
        logger.warn("Database connection slow")
        logger.error("Failed to authenticate user")
        logger.debug("Processing request", user_id: 123, action: "login")
        logger.progname = "TestService"
        logger.info("Service started", service: "test")
      end
    end

    it "can use level as an alias for severity", deprecation_mode: :silent do
      result = logs.closest_match(level: :info, message: "Database connection")
      expect(result).to_not be_nil
      expect(result.message).to eq "Database connection slow"
      expect(result.severity).to eq Logger::WARN
    end

    it "can use tags as an alias for attributes", deprecation_mode: :silent do
      result = logs.closest_match(tags: {user_id: 123})
      expect(result).to_not be_nil
      expect(result.message).to eq "Processing request"
      expect(result.attributes["user_id"]).to eq 123
    end
  end

  describe "#to_s" do
    it "should return a string representation of the captured entries" do
      Lumberjack::CaptureDevice.capture(logger) do |logs|
        expect(logs.to_s).to eq "<#Lumberjack::CaptureDevice 0 entries captured>"
        logger.info("foobar", foo: "bar")
        expect(logs.to_s).to eq "<#Lumberjack::CaptureDevice 1 entry captured>"
      end
    end
  end
end

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

    it "writes captured entries back to the original device when finished" do
      original_device = Lumberjack::Device::Test.new
      logger = Lumberjack::Logger.new(original_device, level: :info)

      Lumberjack::CaptureDevice.capture(logger) do
        logger.info("test message 1")
        logger.warn("test message 2")
        expect(original_device.entries).to eq []
      end

      expect(original_device.entries.collect(&:message)).to include "test message 1"
      expect(original_device.entries.collect(&:message)).to include "test message 2"
    end

    it "does not write captured entries back to the original device when write_to_original is false" do
      output = StringIO.new
      logger = Lumberjack::Logger.new(output, level: :info)

      device = Lumberjack::CaptureDevice.capture(logger, write_to_original: false) do
        logger.info("test message 1")
        logger.warn("test message 2")
        expect(output.string).to eq ""
      end

      expect(output.string).to eq ""
      expect(device.entries.map(&:message)).to eq ["test message 1", "test message 2"]
    end
  end

  describe "#write_to_underlying_device" do
    it "writes captured entries to the underlying device" do
      underlying_device = Lumberjack::Device::Test.new
      logger = Lumberjack::Logger.new(underlying_device, level: :info)
      device = Lumberjack::CaptureDevice.new(underlying_device: underlying_device)
      logger.device = device

      logger.info("test message 1")
      logger.warn("test message 2")

      expect(underlying_device.entries).to be_empty
      device.write_to_underlying_device
      expect(underlying_device.entries.map(&:message)).to match_array ["test message 1", "test message 2"]
    end

    it "adds the additional attributes to each entry" do
      underlying_device = Lumberjack::Device::Test.new
      logger = Lumberjack::Logger.new(underlying_device, level: :info)
      device = Lumberjack::CaptureDevice.new(underlying_device: underlying_device)
      logger.device = device

      logger.info("test message 1", user_id: 123)
      logger.warn("test message 2")

      device.write_to_underlying_device(attributes: {rspec: {description: "test example"}})

      expect(underlying_device).to include(message: "test message 1", attributes: {"user_id" => 123, "rspec.description" => "test example"})
      expect(underlying_device).to include(message: "test message 2", attributes: {"rspec.description" => "test example"})
      expect(device.entries.first.attributes).to eq({"user_id" => 123})
    end
  end

  describe "#initialize" do
    it "honors the max_entries option" do
      device = Lumberjack::CaptureDevice.new(max_entries: 5)
      expect(device.max_entries).to eq 5
    end

    it "defaults max_entries to 1,000,000" do
      device = Lumberjack::CaptureDevice.new
      expect(device.max_entries).to eq 1_000_000
    end
  end

  describe "#include?" do
    it "should match filters with string keys" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar")
      end
      expect(logs.include?("message" => "foobar")).to be true
      expect(logs.include?("message" => "baz")).to be false
    end

    it "should raise an ArgumentError on unrecognized filter keys" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar")
      end
      expect { logs.include?(mesage: "foobar") }.to raise_error(ArgumentError, /mesage/)
    end
  end

  describe "#extract" do
    it "should extract entries from the buffer" do
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
    end

    it "uses the entry formatter to match unformatted filter values" do
      entry_formatter = Lumberjack::EntryFormatter.build do |config|
        config.format_attributes(Exception) { |e| {kind: e.class.name, message: e.message} }
      end
      error = begin
        raise "boom"
      rescue => e
        e
      end

      device = Lumberjack::CaptureDevice.new(entry_formatter: entry_formatter)
      formatted_logger = Lumberjack::Logger.new(device, formatter: entry_formatter)
      formatted_logger.error("failed", error: error)

      expect(device.extract(attributes: {error: error}).collect(&:message)).to eq ["failed"]
      expect(device.extract(attributes: {error: ArgumentError.new("nope")})).to be_empty
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
      expect(logs.inspect).to include "INFO foobar"
      expect(logs.inspect).to include "WARN something happened"
      expect(logs.inspect).to include "foo: bar"
      expect(logs.inspect).to include "duration: 1.23"
      expect(logs.inspect).to include "foo.bar: baz"
      expect(logs.inspect).to include "progname: TestProgname"
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

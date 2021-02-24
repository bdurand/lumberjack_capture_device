# frozen_string_literal: true

require_relative "spec_helper"

describe Lumberjack::CaptureDevice do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, level: :info) }

  describe "capture" do
    it "should capture log entries inside a block to a buffer" do
      buffer = nil
      device = Lumberjack::CaptureDevice.capture(logger) { |logs|
        logger.debug("one")
        expect(logs.buffer.collect(&:message)).to eq ["one"]
        logger.debug("two")
        expect(logs.buffer.collect(&:message)).to eq ["one", "two"]
        buffer = logs.buffer
      }

      logger.info("foo")
      expect(device.buffer).to eq buffer

      device.clear
      expect(device.buffer).to eq []

      expect(logger.level).to eq Logger::INFO
    end
  end

  describe "include" do
    it "should match the log level by label or constant" do
      logs = Lumberjack::CaptureDevice.capture(logger) {
        logger.info("foobar")
      }
      expect(logs).to include(level: :info)
      expect(logs).to include(level: "info")
      expect(logs).to include(level: Logger::INFO)
      expect(logs).to_not include(level: :error)
    end

    it "should match the log message" do
      logs = Lumberjack::CaptureDevice.capture(logger) {
        logger.info("foobar")
      }
      expect(logs).to include(message: "foobar")
      expect(logs).to include(message: /foo/)
      expect(logs).to include(message: instance_of(String))
      expect(logs).to_not include(message: "other")
    end

    it "should match tags" do
      logs = Lumberjack::CaptureDevice.capture(logger) {
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22], three: nil})
      }
      expect(logs).to include(tags: {foo: "bar"})
      expect(logs).to include(tags: {"foo" => "bar"})
      expect(logs).to include(tags: {foo: /b/})
      expect(logs).to include(tags: {foo: anything})
      expect(logs).to_not include(tags: {foo: "other"})
      expect(logs).to include(tags: {baz: {one: 1}})
      expect(logs).to include(tags: {"baz" => {"one" => Integer}})
      expect(logs).to_not include(tags: {baz: {one: "one"}})
      expect(logs).to include(tags: {baz: {one: 1, two: [2, 22]}})
    end

    it "should match combinations" do
      logs = Lumberjack::CaptureDevice.capture(logger) {
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22]})
      }
      expect(logs).to include(level: :info, message: "foobar", tags: {foo: "bar"})
      expect(logs).to include(level: :info, message: "foobar")
      expect(logs).to include(level: :info, tags: {foo: "bar"})
      expect(logs).to include(message: "foobar", tags: {foo: "bar"})
      expect(logs).to_not include(message: "foobar", tags: {foo: "bax"})
      expect(logs).to_not include(level: :warn, message: "foobar")
    end
  end

  describe "extract" do
    it "should extract entries from the buffer" do
      logs = Lumberjack::CaptureDevice.capture(logger) {
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22], three: nil})
        logger.warn("FOOBAR", foo: "bum")
        logger.info("baxbar", foo: "bar")
      }
      expect(logs.extract(message: /foobar/i).collect(&:message)).to eq ["foobar", "FOOBAR"]
      expect(logs.extract(message: /foobar/i, limit: 1).collect(&:message)).to eq ["foobar"]
      expect(logs.extract(level: :info).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(tags: {foo: "bar"}).collect(&:message)).to eq ["foobar", "baxbar"]
    end
  end
end

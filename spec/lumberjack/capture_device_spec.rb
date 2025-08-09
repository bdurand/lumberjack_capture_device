# frozen_string_literal: true

require_relative "../spec_helper"

describe Lumberjack::CaptureDevice do
  let(:logger) { Lumberjack::Logger.new(StringIO.new, level: :info) }

  describe ".capture" do
    it "should capture log entries inside a block to a buffer" do
      buffer = nil
      device = Lumberjack::CaptureDevice.capture(logger) do |logs|
        logger.debug("one")
        expect(logs.buffer.collect(&:message)).to eq ["one"]
        logger.debug("two")
        expect(logs.buffer.collect(&:message)).to eq ["one", "two"]
        buffer = logs.buffer
      end

      logger.info("foo")
      expect(device.buffer).to eq buffer

      device.clear
      expect(device.buffer).to eq []

      expect(logger.level).to eq Logger::INFO
    end
  end

  describe ".formatted_entry" do
    it "should format a log entry into a string" do
      entry = Lumberjack::LogEntry.new(
        Time.new(2023, 1, 1, 12, 0, 0),
        Logger::INFO,
        "Test message",
        "TestProgname",
        1234,
        {foo: "bar", baz: {one: 1, two: 2}}
      )
      expected = <<~STRING
        2023-01-01 12:00:00 INFO: Test message
          progname: TestProgname
          baz.one: 1
          baz.two: 2
          foo: bar
      STRING
      expect(Lumberjack::CaptureDevice.formatted_entry(entry)).to eq(expected.chomp)
    end

    it "should omit nil values" do
      entry = Lumberjack::LogEntry.new(
        Time.new(2023, 1, 1, 12, 0, 0),
        Logger::INFO,
        "Test message",
        nil,
        nil,
        nil
      )
      expected = "2023-01-01 12:00:00 INFO: Test message"
      expect(Lumberjack::CaptureDevice.formatted_entry(entry)).to eq(expected.chomp)
    end

    it "should indent a specified number of spaces" do
      entry = Lumberjack::LogEntry.new(
        Time.new(2023, 1, 1, 12, 0, 0),
        Logger::INFO,
        "Test message",
        "TestProgname",
        1234,
        {foo: "bar"}
      )
      expected = <<~STRING
        2023-01-01 12:00:00 INFO: Test message
          progname: TestProgname
          foo: bar
      STRING
      expected = expected.split("\n").collect { |line| "    #{line}" }.join("\n")
      expect(Lumberjack::CaptureDevice.formatted_entry(entry, indent: 4)).to eq(expected.chomp)
    end
  end

  describe "#include?" do
    it "should match the log level by label or constant" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar")
      end
      expect(logs).to include(level: :info)
      expect(logs).to include(level: "info")
      expect(logs).to include(level: Logger::INFO)
      expect(logs).to_not include(level: :error)
    end

    it "should match the log message" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar")
      end
      expect(logs).to include(message: "foobar")
      expect(logs).to include(message: /foo/)
      expect(logs).to include(message: instance_of(String))
      expect(logs).to_not include(message: "other")
    end

    it "should match the progname" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.progname = "TestProgname"
        logger.info("foobar")
      end
      expect(logs).to include(progname: "TestProgname")
      expect(logs).to include(progname: /Test/)
      expect(logs).to include(progname: instance_of(String))
      expect(logs).to_not include(progname: "OtherProgname")
    end

    it "should match tags" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22], three: nil})
      end
      expect(logs).to include(tags: {foo: "bar"})
      expect(logs).to include(tags: {"foo" => "bar"})
      expect(logs).to include(tags: {foo: /b/})
      expect(logs).to include(tags: {foo: anything})
      expect(logs).to_not include(tags: {foo: "other"})
      expect(logs).to include(tags: {baz: {one: 1}})
      expect(logs).to include(tags: {"baz" => {"one" => Integer}})
      expect(logs).to_not include(tags: {baz: {one: "one"}})
      expect(logs).to include(tags: {baz: {one: 1, two: [2, 22]}})
      expect(logs).to include(tags: {baz: {three: nil}})
    end

    it "should match nil if the tag is not present" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", fip: [])
      end
      expect(logs).to_not include(tags: {foo: nil})
      expect(logs).to include(tags: {baz: nil})
      expect(logs).to include(tags: {fip: nil})
    end

    it "should match empty array if the tag is not present" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", fip: [])
      end
      expect(logs).to_not include(tags: {foo: []})
      expect(logs).to include(tags: {baz: []})
      expect(logs).to include(tags: {fip: []})
    end

    it "should expand dot notation on tag filters" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: {bar: {baz: "boo"}})
      end
      expect(logs).to include(tags: {"foo.bar.baz" => "boo"})
      expect(logs).to_not include(tags: {"foo.bar.baz" => "other"})
      expect(logs).to include(tags: {"foo.bar.baz" => /bo/})
      expect(logs).to include(tags: {"foo.bar" => {"baz" => "boo"}})
      expect(logs).to include(tags: {"foo.bar.baz" => String})
      expect(logs).to_not include(tags: {"foo.bar.baz" => Integer})
    end

    it "should merge dot notation tags" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: {bar: {baz: "boo"}}, "foo.bar": {bip: "bop"}, "foo.bar.qux": "kook")
      end
      expect(logs).to include(tags: {"foo.bar.baz" => "boo"})
    end

    it "should match arrays of hashes" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: [{bar: "baz"}, {bip: "bop"}])
      end
      expect(logs).to include(tags: {foo: [{bar: "baz"}, {bip: "bop"}]})
      expect(logs).to include(tags: {foo: [{"bar" => "baz"}, {"bip" => "bop"}]})
      expect(logs).to include(tags: {foo: array_including({"bar" => "baz"})})
    end

    it "should match combinations" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22]})
      end
      expect(logs).to include(level: :info, message: "foobar", tags: {foo: "bar"})
      expect(logs).to include(level: :info, message: "foobar")
      expect(logs).to include(level: :info, tags: {foo: "bar"})
      expect(logs).to include(message: "foobar", tags: {foo: "bar"})
      expect(logs).to_not include(message: "foobar", tags: {foo: "bax"})
      expect(logs).to_not include(level: :warn, message: "foobar")
    end
  end

  describe "#extract" do
    it "should extract entries from the buffer" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("foobar", foo: "bar", baz: {one: 1, two: [2, 22], three: nil})
        logger.warn("FOOBAR", foo: "bum")
        logger.set_progname("TestProgname") do
          logger.info("baxbar", foo: "bar")
        end
      end
      expect(logs.extract(message: /foobar/i).collect(&:message)).to eq ["foobar", "FOOBAR"]
      expect(logs.extract(message: /foobar/i, limit: 1).collect(&:message)).to eq ["foobar"]
      expect(logs.extract(level: :info).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(tags: {foo: "bar"}).collect(&:message)).to eq ["foobar", "baxbar"]
      expect(logs.extract(progname: "TestProgname").collect(&:message)).to eq ["baxbar"]
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
      expect(logs.inspect).to include "INFO: foobar"
      expect(logs.inspect).to include "WARN: something happened"
      expect(logs.inspect).to include "foo: bar"
      expect(logs.inspect).to include "duration: 1.23"
      expect(logs.inspect).to include "foo.bar: baz"
      expect(logs.inspect).to include "progname: TestProgname"
    end
  end

  describe "#match" do
    it "should return the first match where criteria match" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully")
      end
      result = logs.match(level: :info, message: "User logged in successfully")
      expect(result.message).to eq "User logged in successfully"
      expect(result.severity_label).to eq "INFO"
    end

    it "should return nil when no entry matches" do
      logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User logged in successfully")
      end
      result = logs.match(level: :error, message: "Non-existent message")
      expect(result).to be_nil
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

    it "should return the exact match when criteria match perfectly" do
      result = logs.closest_match(level: :info, message: "User logged in successfully")
      expect(result).to_not be_nil
      expect(result.message).to eq "User logged in successfully"
      expect(result.severity_label).to eq "INFO"
    end

    it "should return the closest match based on string similarity" do
      result = logs.closest_match(level: :info, message: "User login successful")
      expect(result).to_not be_nil
      expect(result.message).to eq "User logged in successfully"
    end

    it "should find matches with level proximity when exact level doesn't match" do
      result = logs.closest_match(level: :info, message: "Database connection")
      expect(result).to_not be_nil
      expect(result.message).to eq "Database connection slow"
      expect(result.severity_label).to eq "WARN"
    end

    it "should match based on tags" do
      result = logs.closest_match(tags: {user_id: 123})
      expect(result).to_not be_nil
      expect(result.message).to eq "Processing request"
      expect(result.tags["user_id"]).to eq 123
    end

    it "should match based on progname" do
      result = logs.closest_match(progname: "TestService")
      expect(result).to_not be_nil
      expect(result.progname).to eq "TestService"
      expect(result.message).to eq "Service started"
    end

    it "should handle regex patterns in message matching" do
      result = logs.closest_match(message: /authenticate/)
      expect(result).to_not be_nil
      expect(result.message).to eq "Failed to authenticate user"
    end

    it "should return nil when no entry meets minimum criteria" do
      result = logs.closest_match(level: :fatal, message: "Completely different message")
      expect(result).to be_nil
    end

    it "should return nil when buffer is empty" do
      empty_logs = Lumberjack::CaptureDevice.new
      result = empty_logs.closest_match(level: :info, message: "test")
      expect(result).to be_nil
    end

    it "should handle multiple criteria and weight them properly" do
      result = logs.closest_match(
        level: :debug,
        message: "Processing",
        tags: {action: "login"}
      )
      expect(result).to_not be_nil
      expect(result.message).to eq "Processing request"
      expect(result.severity_label).to eq "DEBUG"
      expect(result.tags["action"]).to eq "login"
    end

    it "should handle string similarity for progname" do
      result = logs.closest_match(progname: "TestServ")
      expect(result).to_not be_nil
      expect(result.progname).to eq "TestService"
    end

    it "should handle nested tag matching" do
      nested_logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("Nested test", user: {id: 456, name: "John"})
      end

      result = nested_logs.closest_match(tags: {user: {id: 456}})
      expect(result).to_not be_nil
      expect(result.message).to eq "Nested test"
    end

    it "should return the best match when multiple entries partially match" do
      multi_logs = Lumberjack::CaptureDevice.capture(logger) do
        logger.info("User authentication started")
        logger.info("User authentication failed")
        logger.info("User authentication successful")
      end

      result = multi_logs.closest_match(message: "authentication success")
      expect(result).to_not be_nil
      expect(result.message).to eq "User authentication successful"
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

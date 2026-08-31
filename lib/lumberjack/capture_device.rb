# frozen_string_literal: true

require "lumberjack"

module Lumberjack
  # Lumberjack device for capturing log entries into memory to allow them to be inspected
  # for testing purposes.
  class CaptureDevice < Lumberjack::Device::Test
    VERSION = ::File.read(::File.join(__dir__, "..", "..", "VERSION")).strip.freeze

    require_relative "capture_device/include_log_entry_matcher"

    include Enumerable

    class << self
      # Capture the entries written by the logger within a block. Within the block all log
      # entries will be written to a CaptureDevice rather than to the normal output for
      # the logger. In addition, the log level will be set to debug. The logger's formatters
      # remain active, so captured entries contain the same formatted values that would have
      # been logged. The device being written to be both yielded to the block as well as
      # returned by the method call.
      #
      # This method is not thread safe. It swaps the device and log level on the logger
      # itself, so concurrent calls on the same logger will interfere with each other and
      # entries logged by other threads during the block will be captured as well. The log
      # level is set on the current context, so threads spawned within the block may not
      # log at the debug level.
      #
      # @param logger [Lumberjack::Logger] The logger to capture entries from.
      # @param write_to_original [Boolean] If true (the default) the captured entries will be written
      #   back to the original device when the block completes. If false, the captured entries
      #   will not be written back.
      # @yield [device] The block to execute while capturing log entries.
      # @return [Lumberjack::CaptureDevice] The device that captured the log entries.
      # @yieldparam device [Lumberjack::CaptureDevice] The device that will capture the log entries.
      # @example
      #   Lumberjack::CaptureDevice.capture(logger) do |logs|
      #     logger.info("This will be captured")
      #     expect(logs).to include(severity: :info, message: "This will be captured")
      #   end
      #
      # @example
      #   logs = Lumberjack::CaptureDevice.capture(logger) { logger.info("This will be captured") }
      #   expect(logs).to include(severity: :info, message: "This will be captured")
      def capture(logger, write_to_original: true)
        save_device = logger.device
        save_level = logger.level
        device = new(underlying_device: save_device)

        begin
          logger.device = device
          logger.level = :debug
          yield device
        ensure
          logger.device = save_device
          logger.level = save_level
          device.write_to_underlying_device if write_to_original
        end

        device
      end
    end

    # The original device from the logger before capture started.
    #
    # @return [Lumberjack::Device, nil] The original device, or nil if none was set.
    attr_reader :underlying_device

    # Initialize a new CaptureDevice.
    #
    # @param options [Hash] Options to pass to the parent Test device.
    def initialize(options = {})
      @underlying_device = options[:underlying_device]
      super({max_entries: 1_000_000}.merge(options))
    end

    # Return all the captured entries that match the specified filters. The device
    # `entry_formatter` is used to match the filters, so unformatted values can be used in
    # the filters if it is set.
    #
    # For severity, you can specify either a numeric constant (i.e. `Logger::WARN`) or a symbol
    # (i.e. `:warn`).
    #
    # For message and progname you can specify a string to perform an exact match or a regular
    # expression to perform a partial or pattern match. You can also supply any matcher value
    # available in your test library (i.e. in rspec you could use `anything` or `instance_of(Error)`,
    # etc.).
    #
    # @param message [String, Regexp, nil] The message to match against the log entries.
    # @param severity [String, Symbol, Integer, nil] The severity to match against the log entries.
    # @param attributes [Hash, nil] A hash of attribute names to values to match against the log entries. The attributes
    #   will match nested attributes using dot notation (e.g. `foo.bar` will match an attribute with the structure
    #   +{foo: {bar: "value"}}+).
    # @param progname [String, nil] The program name to match against the log entries.
    # @param limit [Integer, nil] The maximum number of entries to return. If nil, all matching entries
    #   will be returned.
    # @return [Array<Lumberjack::LogEntry>] An array of log entries that match the specified filters.
    # @example
    #   logs.extract(severity: :warn, message: /something happened/, attributes: {user: "john"})
    def extract(message: nil, severity: nil, attributes: nil, progname: nil, limit: nil)
      matched = []

      matcher = LogEntryMatcher.new(
        message: message,
        severity: severity,
        attributes: attributes,
        progname: progname,
        formatter: entry_formatter
      )

      entries.each do |entry|
        matched << entry if matcher.match?(entry)
        break if limit && matched.size >= limit
      end

      matched
    end

    # Return true if the captured log entries match the specified filters. The filters are the
    # same as the ones used by the `extract` method.
    #
    # This must be redefined here because Enumerable#include? would otherwise shadow the
    # implementation inherited from Lumberjack::Device::Test.
    #
    # @example
    #   logs.include?(severity: :warn, message: /something happened/, attributes: {user: "john"})
    #
    # @param filters [Hash] The filters to apply to the captured entries.
    # @option filters [String, Regexp] :message The message to match against the log entries.
    # @option filters [String, Symbol, Integer] :severity The severity to match against the log entries.
    # @option filters [Hash] :attributes A hash of attribute names to values to match against the log entries. The attributes
    #   will match nested attributes using dot notation (e.g. `foo.bar` will match an attribute with the structure
    #   +{foo: {bar: "value"}}+).
    # @option filters [String] :progname The program name to match against the log entries.
    # @return [Boolean] True if any entries match the specified filters, false otherwise.
    def include?(filters)
      filters = filters.transform_keys(&:to_sym)
      unknown_keys = filters.keys - [:message, :severity, :attributes, :progname]
      unless unknown_keys.empty?
        raise ArgumentError, "unknown log filters: #{unknown_keys.map(&:inspect).join(", ")}"
      end

      !!match(**filters)
    end

    # Write the captured log entries to the underlying device.
    #
    # @param attributes [Hash, nil] Additional attributes to add to each entry as it is
    #   written. Attributes already set on an entry take precedence over these values.
    # @return [void]
    def write_to_underlying_device(attributes: nil)
      return unless @underlying_device

      if attributes.nil? || attributes.empty?
        write_to(@underlying_device)
      else
        extra_attributes = Lumberjack::Utils.expand_attributes(attributes)
        entries.each do |entry|
          copy = entry.dup
          copy.attributes = extra_attributes.merge(Lumberjack::Utils.expand_attributes(entry.attributes || {}))
          @underlying_device.write(copy)
        end
      end

      nil
    end

    # Provide a detailed string representation showing all captured entries.
    #
    # @return [String] A formatted string showing all captured log entries.
    def inspect
      message = +"<##{self.class.name} #{length} #{(length == 1) ? "entry" : "entries"} captured:\n"
      template = Lumberjack::LocalLogTemplate.new
      entries.each do |entry|
        formatted = template.call(entry).split("\n").collect { |line| "  #{line}" }.join("\n")
        message << formatted
        message << "\n"
      end
      message << ">"
      message
    end

    # Provide a simple string representation showing the count of captured entries.
    #
    # @return [String] A brief description of the captured entries count.
    def to_s
      "<##{self.class.name} #{length} #{(length == 1) ? "entry" : "entries"} captured>"
    end

    # Return a thread-safe copy of all captured log entries. This must be redefined here
    # because Enumerable#entries would otherwise shadow the thread-safe implementation
    # inherited from Lumberjack::Device::Test.
    #
    # @return [Array<Lumberjack::LogEntry>] A copy of all captured log entries.
    def entries
      @lock.synchronize { @buffer.dup }
    end

    # Return the number of captured log entries.
    #
    # @return [Integer] The number of captured entries.
    def length
      entries.length
    end

    alias_method :size, :length

    # Iterate over each captured log entry.
    #
    # @yield [entry] Block to execute for each captured entry.
    # @yieldparam entry [Lumberjack::LogEntry] A captured log entry.
    # @return [Array<Lumberjack::LogEntry>] The captured entries (when no block given).
    def each(&block)
      entries.each(&block)
    end
  end
end

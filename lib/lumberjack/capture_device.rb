# frozen_string_literal: true

require "lumberjack"
require "lumberjack_rspec"

module Lumberjack
  # Lumberjack device for capturing log entries into memory to allow them to be inspected
  # for testing purposes.
  class CaptureDevice < Lumberjack::Device::Test
    VERSION = ::File.read(::File.join(__dir__, "..", "..", "VERSION")).strip.freeze

    include Enumerable

    # TODO: remove when this deprecated class is removed.
    autoload :IncludeLogEntryMatcher, "lumberjack/capture_device/include_log_entry_matcher"

    class << self
      # Capture the entries written by the logger within a block. Within the block all log
      # entries will be written to a CaptureDevice rather than to the normal output for
      # the logger. In addition, all formatters will be removed and the log level will be set
      # to debug. The device being written to be both yielded to the block as well as returned
      # by the method call.
      #
      # @param logger [Lumberjack::Logger] The logger to capture entries from.
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
      def capture(logger)
        device = new
        save_device = logger.device
        save_level = logger.level
        save_formatter = logger.formatter
        begin
          logger.device = device
          logger.level = :debug
          logger.formatter = Lumberjack::Formatter.new
          yield device
        ensure
          logger.device = save_device
          logger.level = save_level
          logger.formatter = save_formatter
        end
        device
      end
    end

    # Initialize a new CaptureDevice.
    #
    # @param options [Hash] Options to pass to the parent Test device.
    def initialize(options = {})
      super(options.merge(max_entries: 1_000_000))
    end

    # Return all the captured entries that match the specified filters. These filters are
    # the same as described in the `include?` method.
    #
    # @param message [String, Regexp, nil] The message to match against the log entries.
    # @param severity [String, Symbol, Integer, nil] The severity to match against the log entries.
    # @param attributes [Hash, nil] A hash of attribute names to values to match against the log entries. The attributes
    #   will match nested attributes using dot notation (e.g. `foo.bar` will match an attribute with the structure
    #   +{foo: {bar: "value"}}+).
    # @param progname [String, nil] The program name to match against the log entries.
    # @param limit [Integer, nil] The maximum number of entries to return. If nil, all matching entries
    #   will be returned.
    # @param level [String, Symbol, Integer, nil] Alias for the `severity` parameter.
    # @param tags [Hash, nil] Alias for the `attributes` parameter.
    # @return [Array<Lumberjack::LogEntry>] An array of log entries that match the specified filters.
    def extract(message: nil, severity: nil, attributes: nil, progname: nil, limit: nil, level: nil, tags: nil)
      matched = []
      if severity.nil? && !level.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#extract(level)", "Lumberjack::CaptureDevice#extract level parameter has been renamed to severity; it will be removed in version 2.1.")
        severity = level
      end
      if attributes.nil? && !tags.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#extract(tags)", "Lumberjack::CaptureDevice#extract tags parameter has been renamed to attributes; it will be removed in version 2.1.")
        attributes = tags
      end

      matcher = LogEntryMatcher.new(message: message, severity: severity, attributes: attributes, progname: progname)

      entries.each do |entry|
        matched << entry if matcher.match?(entry)
        break if limit && matched.size >= limit
      end

      matched
    end

    # Return true if the captured log entries match the specified level, message, and attributes.
    #
    # For level, you can specify either a numeric constant (i.e. `Logger::WARN`) or a symbol
    # (i.e. `:warn`).
    #
    # For message you can specify a string to perform an exact match or a regular expression
    # to perform a partial or pattern match. You can also supply any matcher value available
    # in your test library (i.e. in rspec you could use `anything` or `instance_of(Error)`, etc.).
    #
    # For attributes, you can specify a hash of attribute names to values to match. You can use
    # regular expression or matchers as the values here as well. attributes can also be nested to match
    # nested attributes.
    #
    # @example
    #   logs.include?(level: :warn, message: /something happened/, attributes: {user: "john"})
    #
    # @param filters [Hash] The filters to apply to the captured entries.
    # @option filters [String, Regexp] :message The message to match against the log entries.
    # @option filters [String, Symbol, Integer] :severity The log level to match against the log entries.
    # @option filters [Hash] :attributes A hash of attribute names to values to match against the log entries. The attributes
    #   will match nested attributes using dot notation (e.g. `foo.bar` will match an attribute with the structure
    #   +{foo: {bar: "value"}}+).
    # @option filters [String] :progname The program name to match against the log entries.
    # @option filters [String, Symbol, Integer, nil] :level Alias for the `severity` option. This option is deprecated.
    # @option filters [Hash, nil] :tags Alias for the `attributes` option. This option is deprecated.
    # @return [Boolean] True if any entries match the specified filters, false otherwise.
    def include?(filters)
      if filters.include?(:level)
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#include?(level)", "Lumberjack::CaptureDevice#include? level option has been renamed to severity; it will be removed in version 2.1.")
      end

      if filters.include?(:tags)
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#include?(tags)", "Lumberjack::CaptureDevice#include? tags option has been renamed to attributes; it will be removed in version 2.1.")
      end

      munged_filters = {
        message: filters[:message],
        severity: filters[:severity] || filters[:level],
        attributes: filters[:attributes] || filters[:tags],
        progname: filters[:progname]
      }.compact

      !!match(**munged_filters)
    end

    # Return the first captured entry that matches the filters.
    #
    # @param message [String, Regexp, nil] The message to match against the log entries.
    # @param severity [String, Symbol, Integer, nil] The log level to match against the log entries.
    # @param attributes [Hash, nil] A hash of attribute names to values to match against the log entries. The attributes
    #   will match nested attributes using dot notation (e.g. `foo.bar` will match an attribute with the structure
    #   +{foo: {bar: "value"}}+).
    # @param progname [String, nil] The program name to match against the log entries.
    # @param level [String, Symbol, Integer, nil] Alias for the `severity` parameter. This parameter is deprecated.
    # @param tags [Hash, nil] Alias for the `attributes` parameter. This parameter is deprecated.
    # @return [Lumberjack::LogEntry, nil] The first matching log entry, or nil if no match is found.
    def match(message: nil, severity: nil, attributes: nil, progname: nil, level: nil, tags: nil)
      unless level.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#match(level)", "Lumberjack::CaptureDevice#match level parameter has been renamed to severity; it will be removed in version 2.1.")
      end
      unless tags.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#match(tags)", "Lumberjack::CaptureDevice#match tags parameter has been renamed to attributes; it will be removed in version 2.1.")
      end

      super(message: message, severity: severity || level, attributes: attributes || tags, progname: progname)
    end

    # Return the log entry that most closely matches the specified filters. This method
    # uses fuzzy matching logic to find the best match when no exact match exists.
    # The matching score is calculated based on how many criteria are met and how closely
    # they match. Returns nil if no entry meets the minimum matching criteria.
    #
    # @param message [String, Regexp, nil] The message to match against the log entries.
    # @param severity [String, Symbol, Integer, nil] The severity to match against the log entries.
    # @param attributes [Hash, nil] A hash of attribute names to values to match against the log entries.
    # @param progname [String, nil] The program name to match against the log entries.
    # @param level [String, Symbol, Integer, nil] Alias for the `severity` parameter.
    # @param tags [Hash, nil] Alias for the `attributes` parameter.
    # @return [Lumberjack::LogEntry, nil] The log entry that most closely matches the filters, or nil if no entry meets minimum criteria.
    def closest_match(message: nil, severity: nil, attributes: nil, progname: nil, level: nil, tags: nil)
      return nil if length == 0

      unless level.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#closest_match(level)", "Lumberjack::CaptureDevice#closest_match level parameter has been renamed to severity; it will be removed in version 2.1.")
      end
      unless tags.nil?
        Lumberjack::Utils.deprecated("Lumberjack::CaptureDevice#closest_match(tags)", "Lumberjack::CaptureDevice#closest_match tags parameter has been renamed to attributes; it will be removed in version 2.1.")
      end

      super(
        message: message,
        severity: severity || level,
        attributes: attributes || tags,
        progname: progname
      )
    end

    # Clears all captured log entries.
    #
    # @return [void]
    def clear
      flush
    end

    # Provide a detailed string representation showing all captured entries.
    #
    # @return [String] A formatted string showing all captured log entries.
    def inspect
      message = +"<##{self.class.name} #{length} #{(length == 1) ? "entry" : "entries"} captured:"
      entries.each do |entry|
        message << "\n  #{Lumberjack::CaptureDevice.formatted_entry(entry)}"
      end
      message << "\n>"
      message
    end

    # Provide a simple string representation showing the count of captured entries.
    #
    # @return [String] A brief description of the captured entries count.
    def to_s
      "<##{self.class.name} #{length} #{(length == 1) ? "entry" : "entries"} captured>"
    end

    # Return the number of captured log entries.
    #
    # @return [Integer] The number of captured entries.
    def length
      @buffer.length
    end

    alias_method :size, :length

    # Iterate over each captured log entry.
    #
    # @yield [entry] Block to execute for each captured entry.
    # @yieldparam entry [Lumberjack::LogEntry] A captured log entry.
    # @return [Array<Lumberjack::LogEntry>] The captured entries (when no block given).
    def each(&block)
      @buffer.each(&block)
    end
  end
end

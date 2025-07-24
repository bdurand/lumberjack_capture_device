# frozen_string_literal: true

require "lumberjack"

module Lumberjack
  # Lumberjack device for capturing log entries into memory to allow them to be inspected
  # for testing purposes.
  class CaptureDevice < Lumberjack::Device
    attr_reader :buffer

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
      #     expect(logs).to include(level: :info, message: "This will be captured")
      #   end
      #
      # @example
      #   logs = Lumberjack::CaptureDevice.capture(logger) { logger.info("This will be captured") }
      #   expect(logs).to include(level: :info, message: "This will be captured")
      def capture(logger)
        device = new
        save_device = logger.device
        save_level = logger.level
        save_formatter = logger.formatter
        begin
          logger.device = device
          logger.level = :debug
          logger.formatter = Lumberjack::Formatter.empty
          yield device
        ensure
          logger.device = save_device
          logger.level = save_level
          logger.formatter = save_formatter
        end
        device
      end
    end

    def initialize
      @buffer = []
    end

    def write(entry)
      @buffer << entry
    end

    # Clear all entries that have been written to the buffer.
    def clear
      @buffer.clear
    end

    # Return true if the captured log entries match the specified level, message, and tags.
    #
    # For level, you can specified either a numeric constant (i.e. `Logger::WARN`) or a symbol
    # (i.e. `:warn`).
    #
    # For message you can specify a string to perform an exact match or a regular expression
    # to perform a partial or pattern match. You can also supply any matcher value available
    # in your test library (i.e. in rspec you could use `anything` or `instance_of(Error)`, etc.).
    #
    # For tags, you can specify a hash of tag names to values to match. You can use
    # regular expression or matchers as the values here as well. Tags can also be nested to match
    # nested tags.
    #
    # Example:
    #
    # ```
    # logs.include(level: :warn, message: /something happened/, tags: {duration: instance_of(Float)})
    # ```
    #
    # @param args [Hash] The filters to apply to the captured entries.
    # @option args [String, Regexp] :message The message to match against the log entries.
    # @option args [String, Symbol, Integer] :level The log level to match against the log entries.
    # @option args [Hash] :tags A hash of tag names to values to match against the log entries. The tags
    #   will match nested tags using dot notation (e.g. `foo.bar` will match a tag with the structure
    #   `{foo: {bar: "value"}}`).
    # @return [Boolean] True if any entries match the specified filters, false otherwise.
    def include?(args)
      !extract(**args.merge(limit: 1)).empty?
    end

    # Return all the captured entries that match the specified filters. These filters are
    # the same as described in the `include?` method.
    #
    # @param message [String, Regexp, nil] The message to match against the log entries.
    # @param level [String, Symbol, Integer, nil] The log level to match against the log entries.
    # @param tags [Hash, nil] A hash of tag names to values to match against the log entries. The tags
    #   will match nested tags using dot notation (e.g. `foo.bar` will match a tag with the structure
    #   `{foo: {bar: "value"}}`).
    # @param limit [Integer, nil] The maximum number of entries to return. If nil, all matching entries
    #   will be returned.
    # @return [Array<Lumberjack::Entry>] An array of log entries that match the specified filters.
    def extract(message: nil, level: nil, tags: nil, limit: nil)
      matches = []

      if level
        # Normalize the level filter to numeric values.
        level = (level.is_a?(Integer) ? level : Lumberjack::Severity.label_to_level(level))
      end
      @buffer.each do |entry|
        if matched?(entry, message, level, tags)
          matches << entry
          break if limit && matches.size >= limit
        end
      end

      matches
    end

    def inspect
      message = +"<##{self.class.name} #{@buffer.size} #{(@buffer.size == 1) ? "entry" : "entries"} captured:"
      @buffer.each do |entry|
        message << "\n  #{formatted_entry(entry)}"
      end
      message << "\n>"
      message
    end

    private

    def matched?(entry, message_filter, level_filter, tags_filter)
      return false unless match?(entry.message, message_filter)
      return false unless match?(entry.severity, level_filter)

      if tags_filter.is_a?(Hash)
        tags_filter = deep_stringify_keys(Lumberjack::Utils.expand_tags(tags_filter))
      end
      tags = deep_stringify_keys(Lumberjack::Utils.expand_tags(entry.tags))

      return false unless match_tags?(tags, tags_filter)

      true
    end

    def match?(value, filter)
      return true unless filter
      filter === value
    end

    def match_tags?(tags, filter)
      return true unless filter
      return false unless tags

      filter.all? do |name, value_filter|
        name = name.to_s
        tag_values = tags[name]
        if tag_values.is_a?(Hash)
          if value_filter.is_a?(Hash)
            match_tags?(tag_values, value_filter)
          else
            false
          end
        elsif value_filter.nil? || (value_filter.is_a?(Enumerable) && value_filter.empty?)
          tag_values.nil? || (tag_values.is_a?(Array) && tag_values.empty?)
        elsif tags.include?(name)
          match?(tag_values, value_filter)
        else
          false
        end
      end
    end

    def deep_stringify_keys(hash)
      if hash.is_a?(Hash)
        hash.each_with_object({}) do |(key, value), result|
          new_key = key.to_s
          new_value = deep_stringify_keys(value)
          result[new_key] = new_value
        end
      elsif hash.is_a?(Enumerable)
        hash.collect { |item| deep_stringify_keys(item) }
      else
        hash
      end
    end

    def formatted_entry(entry)
      timestamp = entry.time.strftime("%Y-%m-%d %H:%M:%S")
      formatted = +"#{timestamp} #{entry.severity_label}: #{entry.message}"
      formatted << "\n    progname: #{entry.progname}" if entry.progname.to_s != ""
      formatted << "\n    pid: #{entry.pid}" if entry.pid
      if entry.tags && !entry.tags.empty?
        Lumberjack::Utils.flatten_tags(entry.tags).to_a.sort_by(&:first).each do |name, value|
          formatted << "\n    #{name}: #{value}"
        end
      end
      formatted
    end
  end
end

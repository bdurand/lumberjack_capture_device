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
    def include?(args)
      !extract(**args.merge(limit: 1)).empty?
    end

    # Return all the captured entries that match the specified filters. These filters are
    # the same as described in the `include?` method.
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

    private

    def matched?(entry, message_filter, level_filter, tags_filter)
      match?(entry.message, message_filter) && match?(entry.severity, level_filter) && match_tags?(entry.tags, tags_filter)
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
            match_tags?(Lumberjack::Tags.stringify_keys(tag_values), value_filter)
          else
            false
          end
        elsif tag_values || tags.include?(name)
          match?(tag_values, value_filter)
        else
          false
        end
      end
    end
  end
end

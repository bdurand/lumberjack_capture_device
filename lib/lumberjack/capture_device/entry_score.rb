# frozen_string_literal: true

# Class responsible for scoring and matching log entries against filters
class Lumberjack::CaptureDevice::EntryScore
  # Minimum score threshold for considering a match (30% match)
  MIN_SCORE_THRESHOLD = 0.3

  class << self
    # Calculate the overall match score for an entry against all provided filters
    # Returns a score between 0.0 and 1.0
    def calculate_match_score(entry, message_filter, severity_filter, tags_filter, progname_filter)
      scores = []
      weights = []

      # Check message match
      if message_filter
        message_score = calculate_field_score(entry.message, message_filter)
        scores << message_score
        weights << 0.4  # Weight message matching highly
      end

      # Check severity match
      if severity_filter
        severity_score = if entry.severity == severity_filter
          1.0  # Exact severity match
        else
          severity_proximity_score(entry.severity, severity_filter)  # Partial severity match
        end
        scores << severity_score
        weights << 0.3
      end

      # Check progname match
      if progname_filter
        progname_score = calculate_field_score(entry.progname, progname_filter)
        scores << progname_score
        weights << 0.2
      end

      # Check tags match
      if tags_filter.is_a?(Hash) && !tags_filter.empty?
        tags_score = calculate_tags_score(entry.tags, tags_filter)
        scores << tags_score
        weights << 0.3
      end

      # Return 0 if no criteria were provided
      return 0.0 if scores.empty?

      # Calculate weighted average, but apply a penalty if any score is 0
      # This ensures that completely failed criteria significantly impact the result
      total_weighted_score = scores.zip(weights).map { |score, weight| score * weight }.sum
      total_weight = weights.sum
      base_score = total_weighted_score / total_weight

      # Apply penalty for zero scores: reduce the score based on how many criteria completely failed
      zero_scores = scores.count(0.0)
      if zero_scores > 0
        penalty_factor = 1.0 - (zero_scores.to_f / scores.length * 0.5)  # Up to 50% penalty
        base_score *= penalty_factor
      end

      base_score
    end

    # Calculate score for any field value against a filter
    # Returns a score between 0.0 and 1.0 based on how well the value matches the filter
    def calculate_field_score(value, filter)
      return 0.0 unless value && filter

      case filter
      when String
        value_str = value.to_s
        if value_str == filter
          1.0
        elsif value_str.include?(filter)
          0.7
        else
          # Use string similarity for partial matching
          similarity = string_similarity(value_str, filter)
          (similarity > 0.5) ? similarity * 0.6 : 0.0
        end
      when Regexp
        filter.match?(value.to_s) ? 1.0 : 0.0
      else
        # For other matchers (like RSpec matchers), try to use === operator
        begin
          (filter === value) ? 1.0 : 0.0
        rescue
          0.0
        end
      end
    end

    # Calculate proximity score based on log severity distance
    def severity_proximity_score(entry_severity, filter_severity)
      severity_diff = (entry_severity - filter_severity).abs
      case severity_diff
      when 0 then 1.0
      when 1 then 0.7
      when 2 then 0.4
      else 0.0
      end
    end

    # Calculate score for tag matching
    def calculate_tags_score(entry_tags, tags_filter)
      return 0.0 unless entry_tags && tags_filter.is_a?(Hash)

      tags_filter = deep_stringify_keys(Lumberjack::Utils.expand_tags(tags_filter))
      tags = deep_stringify_keys(Lumberjack::Utils.expand_tags(entry_tags))

      total_tag_filters = count_tag_filters(tags_filter)
      return 0.0 if total_tag_filters == 0

      matched_tags = count_matched_tags(tags, tags_filter)
      matched_tags.to_f / total_tag_filters
    end

    private

    # Calculate string similarity using a simple Levenshtein distance-based approach
    # Returns a score between 0.0 and 1.0 where 1.0 is an exact match
    def string_similarity(str1, str2)
      return 1.0 if str1 == str2
      return 0.0 if str1.nil? || str2.nil? || str1.empty? || str2.empty?

      # Convert to lowercase for case-insensitive comparison
      s1 = str1.downcase
      s2 = str2.downcase

      # If one string contains the other, give it a good score
      if s1.include?(s2) || s2.include?(s1)
        shorter = [s1.length, s2.length].min
        longer = [s1.length, s2.length].max
        return shorter.to_f / longer * 0.8 + 0.2  # Boost score for containment
      end

      # Calculate Levenshtein distance
      distance = levenshtein_distance(s1, s2)
      max_length = [s1.length, s2.length].max

      # Convert distance to similarity score
      return 0.0 if max_length == 0
      1.0 - (distance.to_f / max_length)
    end

    # Simple Levenshtein distance implementation
    def levenshtein_distance(str1, str2)
      return str2.length if str1.empty?
      return str1.length if str2.empty?

      matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }

      # Initialize first row and column
      (0..str1.length).each { |i| matrix[i][0] = i }
      (0..str2.length).each { |j| matrix[0][j] = j }

      # Fill the matrix
      (1..str1.length).each do |i|
        (1..str2.length).each do |j|
          cost = (str1[i - 1] == str2[j - 1]) ? 0 : 1
          matrix[i][j] = [
            matrix[i - 1][j] + 1,     # deletion
            matrix[i][j - 1] + 1,     # insertion
            matrix[i - 1][j - 1] + cost # substitution
          ].min
        end
      end

      matrix[str1.length][str2.length]
    end

    def count_tag_filters(tags_filter, count = 0)
      tags_filter.each do |_name, value_filter|
        if value_filter.is_a?(Hash)
          count = count_tag_filters(value_filter, count)
        else
          count += 1
        end
      end
      count
    end

    def count_matched_tags(tags, tags_filter, count = 0)
      return count unless tags && tags_filter

      tags_filter.each do |name, value_filter|
        name = name.to_s
        tag_values = tags[name]

        if value_filter.is_a?(Hash) && tag_values.is_a?(Hash)
          count = count_matched_tags(tag_values, value_filter, count)
        elsif tags.include?(name) && exact_match?(tag_values, value_filter)
          count += 1
        end
      end
      count
    end

    def exact_match?(value, filter)
      return true unless filter
      filter === value
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
  end
end

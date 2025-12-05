# frozen_string_literal: true

# app/models/concerns/time_parsing.rb
#
# Shared module for parsing time strings into minutes since midnight.
# Provides consistent time parsing across models and validators.
#
# Usage in models:
#   include TimeParsing
#   minutes = parse_time_to_minutes("09:30")  # => 570
#
# Usage in validators (class method):
#   TimeParsing.parse_time_to_minutes("14:00")  # => 840
#
module TimeParsing
  extend ActiveSupport::Concern

  # Time format regex constant for validation (HH:MM format)
  TIME_FORMAT_REGEX = /\A([01]?[0-9]|2[0-3]):([0-5][0-9])\z/

  # Parse time string or duration into minutes
  #
  # This method handles two use cases:
  # 1. Time-of-day: "HH:MM" format converted to minutes since midnight
  # 2. Duration: Numeric string (e.g., "60") representing minutes directly
  #
  # @param time_string [String, Integer] Time in "HH:MM" format, numeric string, or integer
  # @return [Integer, nil] Total minutes, or nil if invalid
  #
  # @example Time-of-day (minutes since midnight)
  #   parse_time_to_minutes("09:00")   # => 540
  #   parse_time_to_minutes("9:30")    # => 570
  #   parse_time_to_minutes("23:59")   # => 1439
  #
  # @example Duration (minutes directly)
  #   parse_time_to_minutes("60")      # => 60 (60 minutes)
  #   parse_time_to_minutes("90")      # => 90 (90 minutes)
  #   parse_time_to_minutes(540)       # => 540 (Integer pass-through)
  #
  # @example Invalid formats
  #   parse_time_to_minutes("")        # => nil
  #   parse_time_to_minutes(nil)       # => nil
  #   parse_time_to_minutes("25:00")   # => nil (invalid hour for time-of-day)
  #   parse_time_to_minutes("12:60")   # => nil (invalid minutes)
  #   parse_time_to_minutes("abc")     # => nil (invalid format)
  #
  def parse_time_to_minutes(time_string)
    TimeParsing.parse_time_to_minutes(time_string)
  end

  # Class method version for use in validators and non-instance contexts
  def self.parse_time_to_minutes(time_string)
    return nil if time_string.blank?

    # Accept integers directly (already in minutes)
    return time_string if time_string.is_a?(Integer)

    # Convert string to string (handles cases where it might be a symbol or other type)
    time_string = time_string.to_s

    # Accept pure numeric strings (duration in minutes, e.g., "60" for 60 minutes)
    # This is used for duration fields like appointment_duration_minutes
    return time_string.to_i if time_string.match?(/^\d+$/)

    # Validate time-of-day format: HH:MM where HH is 0-23 and MM is 0-59
    # Allows single-digit hours (9:00) or double-digit (09:00)
    if time_string.match?(TIME_FORMAT_REGEX)
      hours, minutes = time_string.split(":").map(&:to_i)
      (hours * 60) + minutes
    else
      nil
    end
  end

  # Parse time string into a hash with hour and minute components
  #
  # @param time_str [String] Time in "HH:MM" format
  # @return [Hash, nil] Hash with :hour and :minute keys, or nil if invalid
  #
  # @example
  #   parse_time_string("09:30")  # => { hour: 9, minute: 30 }
  #   parse_time_string("invalid") # => nil
  #
  def parse_time_string(time_str)
    TimeParsing.parse_time_string(time_str)
  end

  def self.parse_time_string(time_str)
    return nil if time_str.blank?

    if time_str.match?(TIME_FORMAT_REGEX)
      hours, minutes = time_str.split(":").map(&:to_i)
      { hour: hours, minute: minutes }
    else
      nil
    end
  end

  # Check if a time string is in valid format
  #
  # @param time_string [String] Time in "HH:MM" format
  # @return [Boolean] true if valid format
  def self.valid_time_format?(time_string)
    return false if time_string.blank?
    time_string.to_s.match?(TIME_FORMAT_REGEX)
  end
end

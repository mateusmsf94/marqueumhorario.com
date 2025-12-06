# frozen_string_literal: true

# Service that handles subtracting time ranges from periods
# Encapsulates the complex overlap detection logic with 5 distinct cases
class PeriodSubtractorService
  # Subtract a time range from a list of periods
  # @param periods [Array<TimePeriod>] current available periods
  # @param time_range [TimePeriod] time range to subtract
  # @return [Array<TimePeriod>] periods after subtraction
  def self.call(periods, time_range)
    new(periods, time_range).call
  end

  def initialize(periods, time_range)
    @periods = periods
    @range_start = time_range.start_time
    @range_end = time_range.end_time
  end

  def call
    @periods.flat_map do |period|
      subtract_range_from_period(period)
    end
  end

  private

  attr_reader :periods, :range_start, :range_end

  def subtract_range_from_period(period)
    return [ period ] if no_overlap?(period)
    return [] if complete_overlap?(period)
    return [ keep_end_portion(period) ] if overlaps_start?(period)
    return [ keep_start_portion(period) ] if overlaps_end?(period)
    return split_period(period) if splits_period?(period)

    []
  end

  # Case 1: No overlap - keep the entire period
  def no_overlap?(period)
    range_end <= period.start_time || range_start >= period.end_time
  end

  # Case 2: Range completely covers period
  def complete_overlap?(period)
    range_start <= period.start_time && range_end >= period.end_time
  end

  # Case 3: Range overlaps the start
  def overlaps_start?(period)
    range_start <= period.start_time &&
      range_end > period.start_time &&
      range_end < period.end_time
  end

  def keep_end_portion(period)
    TimePeriod.new(start_time: range_end, end_time: period.end_time)
  end

  # Case 4: Range overlaps the end
  def overlaps_end?(period)
    range_start > period.start_time &&
      range_start < period.end_time &&
      range_end >= period.end_time
  end

  def keep_start_portion(period)
    TimePeriod.new(start_time: period.start_time, end_time: range_start)
  end

  # Case 5: Range splits the period
  def splits_period?(period)
    range_start > period.start_time && range_end < period.end_time
  end

  def split_period(period)
    [
      TimePeriod.new(start_time: period.start_time, end_time: range_start),
      TimePeriod.new(start_time: range_end, end_time: period.end_time)
    ]
  end
end

# frozen_string_literal: true

require "test_helper"

class PeriodSubtractorServiceTest < ActiveSupport::TestCase
  test "case 1: no overlap - keeps entire period when range ends before period starts" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("08:00"), end_time: Time.zone.parse("09:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal period, result.first
  end

  test "case 1: no overlap - keeps entire period when range starts after period ends" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("13:00"), end_time: Time.zone.parse("14:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal period, result.first
  end

  test "case 2: complete overlap - removes period when range completely covers it" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("13:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 0, result.size
  end

  test "case 2: complete overlap - removes period when range exactly matches it" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 0, result.size
  end

  test "case 3: overlaps start - keeps end portion when range overlaps beginning" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("11:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal Time.zone.parse("11:00"), result.first.start_time
    assert_equal Time.zone.parse("12:00"), result.first.end_time
  end

  test "case 4: overlaps end - keeps start portion when range overlaps ending" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("13:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal Time.zone.parse("10:00"), result.first.start_time
    assert_equal Time.zone.parse("11:00"), result.first.end_time
  end

  test "case 5: splits period - creates two periods when range is in the middle" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("14:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("12:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 2, result.size
    assert_equal Time.zone.parse("10:00"), result[0].start_time
    assert_equal Time.zone.parse("11:00"), result[0].end_time
    assert_equal Time.zone.parse("12:00"), result[1].start_time
    assert_equal Time.zone.parse("14:00"), result[1].end_time
  end

  test "handles multiple periods with different overlap scenarios" do
    periods = [
      TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("10:00")), # no overlap
      TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00")), # complete overlap
      TimePeriod.new(start_time: Time.zone.parse("13:00"), end_time: Time.zone.parse("15:00"))  # partial overlap (end)
    ]
    time_range = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("14:00"))

    result = PeriodSubtractorService.call(periods, time_range)

    assert_equal 2, result.size
    # First period unchanged (no overlap)
    assert_equal Time.zone.parse("09:00"), result[0].start_time
    assert_equal Time.zone.parse("10:00"), result[0].end_time
    # Third period truncated (overlaps end)
    assert_equal Time.zone.parse("14:00"), result[1].start_time
    assert_equal Time.zone.parse("15:00"), result[1].end_time
  end

  test "handles empty periods array" do
    time_range = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    result = PeriodSubtractorService.call([], time_range)

    assert_equal 0, result.size
  end

  test "handles multiple sequential subtractions" do
    periods = [
      TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("17:00"))
    ]

    # First subtraction: 11:00-12:00
    time_range1 = TimePeriod.new(start_time: Time.zone.parse("11:00"), end_time: Time.zone.parse("12:00"))
    result = PeriodSubtractorService.call(periods, time_range1)
    assert_equal 2, result.size

    # Second subtraction: 14:00-15:00
    time_range2 = TimePeriod.new(start_time: Time.zone.parse("14:00"), end_time: Time.zone.parse("15:00"))
    result = PeriodSubtractorService.call(result, time_range2)
    assert_equal 3, result.size

    # Verify final periods
    assert_equal Time.zone.parse("09:00"), result[0].start_time
    assert_equal Time.zone.parse("11:00"), result[0].end_time
    assert_equal Time.zone.parse("12:00"), result[1].start_time
    assert_equal Time.zone.parse("14:00"), result[1].end_time
    assert_equal Time.zone.parse("15:00"), result[2].start_time
    assert_equal Time.zone.parse("17:00"), result[2].end_time
  end

  test "handles edge case where range_end equals period start_time (boundary)" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("08:00"), end_time: Time.zone.parse("10:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal period, result.first
  end

  test "handles edge case where range_start equals period end_time (boundary)" do
    period = TimePeriod.new(start_time: Time.zone.parse("10:00"), end_time: Time.zone.parse("12:00"))
    time_range = TimePeriod.new(start_time: Time.zone.parse("12:00"), end_time: Time.zone.parse("14:00"))

    result = PeriodSubtractorService.call([ period ], time_range)

    assert_equal 1, result.size
    assert_equal period, result.first
  end
end

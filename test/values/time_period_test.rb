require "test_helper"

class TimePeriodTest < ActiveSupport::TestCase
  test "creates period with start and end times" do
    start = Time.zone.parse("2025-01-01 09:00")
    finish = Time.zone.parse("2025-01-01 17:00")

    period = TimePeriod.new(start_time: start, end_time: finish)

    assert_equal start, period.start_time
    assert_equal finish, period.end_time
  end

  test "calculates duration in seconds" do
    start = Time.zone.parse("2025-01-01 09:00")
    finish = Time.zone.parse("2025-01-01 17:00")

    period = TimePeriod.new(start_time: start, end_time: finish)

    assert_equal 8.hours.to_i, period.duration.to_i
  end

  test "detects overlapping periods" do
    period1 = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 12:00")
    )

    period2 = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 11:00"),
      end_time: Time.zone.parse("2025-01-01 14:00")
    )

    assert period1.overlaps?(period2), "Period 1 should overlap Period 2"
    assert period2.overlaps?(period1), "Period 2 should overlap Period 1"
  end

  test "detects non-overlapping periods" do
    morning = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 12:00")
    )

    afternoon = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 13:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    refute morning.overlaps?(afternoon), "Morning shouldn't overlap afternoon"
    refute afternoon.overlaps?(morning), "Afternoon shouldn't overlap morning"
  end

  test "detects adjacent periods as non-overlapping" do
    first = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 12:00")
    )

    second = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 12:00"), # Starts exactly when first ends
      end_time: Time.zone.parse("2025-01-01 15:00")
    )

    refute first.overlaps?(second), "Adjacent periods should not overlap"
  end

  test "checks if time is contained within period" do
    period = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    # Time within period
    assert period.contains?(Time.zone.parse("2025-01-01 12:00"))
    assert period.contains?(Time.zone.parse("2025-01-01 09:00")) # Start boundary (inclusive)

    # Time outside period
    refute period.contains?(Time.zone.parse("2025-01-01 08:00")) # Before
    refute period.contains?(Time.zone.parse("2025-01-01 17:00")) # End boundary (exclusive)
    refute period.contains?(Time.zone.parse("2025-01-01 18:00")) # After
  end

  test "is immutable" do
    period = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    assert_raises(NoMethodError) do
      period.start_time = Time.zone.parse("2025-01-01 10:00")
    end
  end

  test "supports equality based on values" do
    period1 = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    period2 = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    period3 = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 10:00"),
      end_time: Time.zone.parse("2025-01-01 17:00")
    )

    assert_equal period1, period2, "Periods with same times should be equal"
    refute_equal period1, period3, "Periods with different times should not be equal"
  end

  test "serializes to hash with ISO8601 timestamps" do
    period = TimePeriod.new(
      start_time: Time.zone.parse("2025-01-01 09:00:00 UTC"),
      end_time: Time.zone.parse("2025-01-01 17:00:00 UTC")
    )

    hash = period.to_h

    assert_equal "2025-01-01T09:00:00Z", hash[:start_time]
    assert_equal "2025-01-01T17:00:00Z", hash[:end_time]
  end
end

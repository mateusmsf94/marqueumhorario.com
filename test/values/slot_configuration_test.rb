# frozen_string_literal: true

require "test_helper"

class SlotConfigurationTest < ActiveSupport::TestCase
  test "should create SlotConfiguration with duration, buffer, and periods" do
    periods = [
      TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("12:00"))
    ]
    config = SlotConfiguration.new(
      duration: 50.minutes,
      buffer: 10.minutes,
      periods: periods
    )

    assert_equal 50.minutes, config.duration
    assert_equal 10.minutes, config.buffer
    assert_equal periods, config.periods
  end

  test "total_slot_duration should return sum of duration and buffer" do
    config = SlotConfiguration.new(
      duration: 50.minutes,
      buffer: 10.minutes,
      periods: []
    )

    assert_equal 60.minutes, config.total_slot_duration
  end

  test "should handle zero buffer" do
    config = SlotConfiguration.new(
      duration: 30.minutes,
      buffer: 0.minutes,
      periods: []
    )

    assert_equal 30.minutes, config.total_slot_duration
  end

  test "should handle empty periods array" do
    config = SlotConfiguration.new(
      duration: 30.minutes,
      buffer: 5.minutes,
      periods: []
    )

    assert_empty config.periods
    assert_equal 35.minutes, config.total_slot_duration
  end

  test "should handle multiple periods" do
    periods = [
      TimePeriod.new(start_time: Time.zone.parse("09:00"), end_time: Time.zone.parse("12:00")),
      TimePeriod.new(start_time: Time.zone.parse("13:00"), end_time: Time.zone.parse("17:00"))
    ]
    config = SlotConfiguration.new(
      duration: 30.minutes,
      buffer: 5.minutes,
      periods: periods
    )

    assert_equal 2, config.periods.size
    assert_equal periods, config.periods
  end
end

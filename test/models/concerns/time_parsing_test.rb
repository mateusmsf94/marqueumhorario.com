require "test_helper"

class TimeParsingTest < ActiveSupport::TestCase
  # Create a test class that includes the concern
  class TestModel
    include TimeParsing
  end

  setup do
    @model = TestModel.new
  end

  # Test instance method: parse_time_to_minutes
  test "parse_time_to_minutes returns correct minutes for valid time string" do
    assert_equal 540, TimeParsing.parse_time_to_minutes("09:00")
    assert_equal 570, TimeParsing.parse_time_to_minutes("09:30")
    assert_equal 1439, TimeParsing.parse_time_to_minutes("23:59")
    assert_equal 0, TimeParsing.parse_time_to_minutes("00:00")
  end

  test "parse_time_to_minutes accepts single-digit hours" do
    assert_equal 480, TimeParsing.parse_time_to_minutes("8:00")
    assert_equal 510, TimeParsing.parse_time_to_minutes("8:30")
  end

  test "parse_time_to_minutes passes through integers unchanged" do
    assert_equal 540, TimeParsing.parse_time_to_minutes(540)
    assert_equal 0, TimeParsing.parse_time_to_minutes(0)
    assert_equal 1439, TimeParsing.parse_time_to_minutes(1439)
  end

  test "parse_time_to_minutes accepts numeric strings as duration in minutes" do
    assert_equal 60, TimeParsing.parse_time_to_minutes("60")
    assert_equal 90, TimeParsing.parse_time_to_minutes("90")
    assert_equal 540, TimeParsing.parse_time_to_minutes("540")
    assert_equal 0, TimeParsing.parse_time_to_minutes("0")
  end

  test "parse_time_to_minutes returns nil for blank input" do
    assert_nil TimeParsing.parse_time_to_minutes("")
    assert_nil TimeParsing.parse_time_to_minutes(nil)
  end

  test "parse_time_to_minutes returns nil for invalid format" do
    assert_nil TimeParsing.parse_time_to_minutes("invalid")
    assert_nil TimeParsing.parse_time_to_minutes("25:00") # Invalid hour for time-of-day
    assert_nil TimeParsing.parse_time_to_minutes("12:60") # Invalid minutes
    assert_nil TimeParsing.parse_time_to_minutes("9:") # Missing minutes value
    assert_nil TimeParsing.parse_time_to_minutes("abc123") # Mixed characters
    assert_nil TimeParsing.parse_time_to_minutes("abc") # Non-numeric
  end

  # Test class method: TimeParsing.parse_time_to_minutes
  test "class method parse_time_to_minutes works without instance" do
    assert_equal 540, TimeParsing.parse_time_to_minutes("09:00")
    assert_equal 570, TimeParsing.parse_time_to_minutes("09:30")
  end

  test "class method returns nil for invalid input" do
    assert_nil TimeParsing.parse_time_to_minutes(nil)
    assert_nil TimeParsing.parse_time_to_minutes("")
    assert_nil TimeParsing.parse_time_to_minutes("invalid")
  end

  test "class method accepts integer input" do
    assert_equal 540, TimeParsing.parse_time_to_minutes(540)
  end

  # Test instance method: parse_time_string
  test "parse_time_string returns hash with hour and minute" do
    result = TimeParsing.parse_time_string("09:30")
    assert_equal({ hour: 9, minute: 30 }, result)
  end

  test "parse_time_string handles midnight" do
    result = TimeParsing.parse_time_string("00:00")
    assert_equal({ hour: 0, minute: 0 }, result)
  end

  test "parse_time_string handles end of day" do
    result = TimeParsing.parse_time_string("23:59")
    assert_equal({ hour: 23, minute: 59 }, result)
  end

  test "parse_time_string accepts single-digit hours" do
    result = TimeParsing.parse_time_string("8:15")
    assert_equal({ hour: 8, minute: 15 }, result)
  end

  test "parse_time_string returns nil for blank input" do
    assert_nil TimeParsing.parse_time_string("")
    assert_nil TimeParsing.parse_time_string(nil)
  end

  test "parse_time_string returns nil for invalid format" do
    assert_nil TimeParsing.parse_time_string("invalid")
    assert_nil TimeParsing.parse_time_string("25:00")
    assert_nil TimeParsing.parse_time_string("12:60")
  end

  # Test class method: TimeParsing.parse_time_string
  test "class method parse_time_string works without instance" do
    result = TimeParsing.parse_time_string("09:30")
    assert_equal({ hour: 9, minute: 30 }, result)
  end

  test "class method parse_time_string returns nil for invalid input" do
    assert_nil TimeParsing.parse_time_string(nil)
    assert_nil TimeParsing.parse_time_string("")
    assert_nil TimeParsing.parse_time_string("invalid")
  end

  # Edge cases
  test "parse_time_to_minutes boundary values" do
    assert_equal 0, TimeParsing.parse_time_to_minutes("0:00")
    assert_equal 1439, TimeParsing.parse_time_to_minutes("23:59")
  end

  test "parse_time_to_minutes validates hour range 0-23" do
    assert_not_nil TimeParsing.parse_time_to_minutes("0:00")
    assert_not_nil TimeParsing.parse_time_to_minutes("23:59")
    assert_nil TimeParsing.parse_time_to_minutes("24:00")
    assert_nil TimeParsing.parse_time_to_minutes("25:00")
  end

  test "parse_time_to_minutes validates minute range 0-59" do
    assert_not_nil TimeParsing.parse_time_to_minutes("12:00")
    assert_not_nil TimeParsing.parse_time_to_minutes("12:59")
    assert_nil TimeParsing.parse_time_to_minutes("12:60")
    assert_nil TimeParsing.parse_time_to_minutes("12:99")
  end

  test "parse_time_to_minutes is consistent with parse_time_string" do
    time_str = "14:30"

    parsed = TimeParsing.parse_time_string(time_str)
    minutes_from_parse = parsed[:hour] * 60 + parsed[:minute]
    minutes_direct = TimeParsing.parse_time_to_minutes(time_str)

    assert_equal minutes_from_parse, minutes_direct
  end

  # Test with various time strings from actual use cases
  test "handles common time strings" do
    # Morning times
    assert_equal 480, TimeParsing.parse_time_to_minutes("08:00")
    assert_equal 540, TimeParsing.parse_time_to_minutes("09:00")

    # Afternoon times
    assert_equal 720, TimeParsing.parse_time_to_minutes("12:00")
    assert_equal 780, TimeParsing.parse_time_to_minutes("13:00")

    # Evening times
    assert_equal 1020, TimeParsing.parse_time_to_minutes("17:00")
    assert_equal 1080, TimeParsing.parse_time_to_minutes("18:00")

    # Late night
    assert_equal 1320, TimeParsing.parse_time_to_minutes("22:00")
    assert_equal 1380, TimeParsing.parse_time_to_minutes("23:00")
  end

  test "handles 15-minute intervals" do
    assert_equal 540, TimeParsing.parse_time_to_minutes("09:00")
    assert_equal 555, TimeParsing.parse_time_to_minutes("09:15")
    assert_equal 570, TimeParsing.parse_time_to_minutes("09:30")
    assert_equal 585, TimeParsing.parse_time_to_minutes("09:45")
  end

  # Test regex pattern matching
  test "accepts all valid HH:MM formats" do
    # Double-digit hours
    assert_not_nil TimeParsing.parse_time_to_minutes("00:00")
    assert_not_nil TimeParsing.parse_time_to_minutes("09:30")
    assert_not_nil TimeParsing.parse_time_to_minutes("12:00")
    assert_not_nil TimeParsing.parse_time_to_minutes("23:59")

    # Single-digit hours
    assert_not_nil TimeParsing.parse_time_to_minutes("0:00")
    assert_not_nil TimeParsing.parse_time_to_minutes("9:30")
  end

  test "rejects invalid HH:MM formats" do
    # Note: Pure numeric strings like "9" are valid (treated as duration in minutes)
    assert_nil TimeParsing.parse_time_to_minutes("9:") # No minutes
    assert_nil TimeParsing.parse_time_to_minutes(":30") # No hours
    assert_nil TimeParsing.parse_time_to_minutes("09:30:00") # Too many parts
    assert_nil TimeParsing.parse_time_to_minutes("9.30") # Wrong separator
    assert_nil TimeParsing.parse_time_to_minutes("9-30") # Wrong separator
    assert_nil TimeParsing.parse_time_to_minutes("abc") # Non-numeric
    assert_nil TimeParsing.parse_time_to_minutes("12:60") # Invalid minutes
  end
end

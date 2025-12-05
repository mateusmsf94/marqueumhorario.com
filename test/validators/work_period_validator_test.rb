require "test_helper"

class WorkPeriodValidatorTest < ActiveSupport::TestCase
  # Create a simple test class that uses WorkPeriodValidator
  class TestRecord
    include ActiveModel::Validations

    attr_accessor :work_periods

    validates_with WorkPeriodValidator
  end

  # Test class with custom attribute name
  class CustomAttributeRecord
    include ActiveModel::Validations

    attr_accessor :schedule_periods

    validates_with WorkPeriodValidator, attribute: :schedule_periods
  end

  # Blank/nil handling
  test "valid when work_periods is nil" do
    record = TestRecord.new
    record.work_periods = nil

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid when work_periods is empty array" do
    record = TestRecord.new
    record.work_periods = []

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  # Valid time format tests
  test "valid with single period in correct format" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "17:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with multiple non-overlapping periods" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "13:00", "end" => "17:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with periods in different order" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "13:00", "end" => "17:00" },
      { "start" => "09:00", "end" => "12:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with adjacent periods (touching but not overlapping)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "12:00", "end" => "17:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with three non-overlapping periods" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "06:00", "end" => "09:00" },
      { "start" => "10:00", "end" => "14:00" },
      { "start" => "15:00", "end" => "20:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with early morning time (single digit hour)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "8:00", "end" => "12:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  test "valid with late night time (23:xx)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "20:00", "end" => "23:59" }
    ]

    assert record.valid?
    assert_empty record.errors[:work_periods]
  end

  # Invalid time format tests
  test "invalid when start time has wrong format (no colon)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "0900", "end" => "17:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "invalid when end time has wrong format (too many digits)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "17:000" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "invalid when time has invalid hour (24+)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "24:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "invalid when time has invalid minutes (60+)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "17:60" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "invalid when time is not a string (integer)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => 900, "end" => "17:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "invalid when time is not a string (Time object)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => Time.zone.parse("09:00"), "end" => "17:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 has invalid time format"
  end

  test "reports correct period number for multiple invalid formats" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },  # Valid
      { "start" => "bad", "end" => "17:00" },    # Invalid - period 2
      { "start" => "18:00", "end" => "20:00" }   # Valid
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 2 has invalid time format"
  end

  # Invalid time range tests (end before start)
  test "invalid when end time equals start time" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "09:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 end time must be after start time"
  end

  test "invalid when end time is before start time" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "17:00", "end" => "09:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 1 end time must be after start time"
  end

  test "invalid when one of multiple periods has end before start" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },  # Valid
      { "start" => "17:00", "end" => "13:00" }   # Invalid
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "period 2 end time must be after start time"
  end

  # Overlapping periods tests
  test "invalid when periods overlap completely" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "17:00" },
      { "start" => "10:00", "end" => "16:00" }  # Completely inside first period
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "09:00-17:00 and 10:00-16:00 overlap"
  end

  test "invalid when periods overlap at start" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "13:00" },
      { "start" => "12:00", "end" => "17:00" }  # Overlaps end of first
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "09:00-13:00 and 12:00-17:00 overlap"
  end

  test "invalid when periods overlap at end" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "13:00", "end" => "17:00" },
      { "start" => "09:00", "end" => "14:00" }  # Overlaps start of first
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "13:00-17:00 and 09:00-14:00 overlap"
  end

  test "invalid when second period completely contains first" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "10:00", "end" => "12:00" },
      { "start" => "09:00", "end" => "17:00" }  # Contains first period
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "10:00-12:00 and 09:00-17:00 overlap"
  end

  test "invalid with one minute overlap" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:01" },
      { "start" => "12:00", "end" => "17:00" }
    ]

    assert_not record.valid?
    assert_includes record.errors[:work_periods].first, "overlap"
  end

  test "invalid when three periods with middle one overlapping both" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "06:00", "end" => "10:00" },
      { "start" => "09:00", "end" => "15:00" },  # Overlaps both
      { "start" => "14:00", "end" => "18:00" }
    ]

    assert_not record.valid?
    # Should have at least one overlap error
    assert_match(/overlap/, record.errors[:work_periods].first)
  end

  # Skipping overlap check when format is invalid
  test "does not check overlaps when format is invalid" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "bad_format", "end" => "12:00" },
      { "start" => "09:00", "end" => "17:00" }
    ]

    assert_not record.valid?
    # Should only have format error, not overlap error
    assert_equal 1, record.errors[:work_periods].size
    assert_includes record.errors[:work_periods].first, "invalid time format"
    assert_not_includes record.errors[:work_periods].first, "overlap"
  end

  test "checks overlaps only after all periods have valid format" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "13:00" },
      { "start" => "12:00", "end" => "17:00" },  # Would overlap if checked
      { "start" => "bad", "end" => "20:00" }     # Invalid format
    ]

    assert_not record.valid?
    # Should have format error but not overlap error since not all valid
    errors_text = record.errors[:work_periods].join(" ")
    assert_includes errors_text, "invalid time format"
  end

  # Custom attribute name
  test "works with custom attribute name" do
    record = CustomAttributeRecord.new
    record.schedule_periods = [
      { "start" => "09:00", "end" => "17:00" }
    ]

    assert record.valid?
    assert_empty record.errors[:schedule_periods]
  end

  test "adds errors to custom attribute" do
    record = CustomAttributeRecord.new
    record.schedule_periods = [
      { "start" => "17:00", "end" => "09:00" }
    ]

    assert_not record.valid?
    assert_not_empty record.errors[:schedule_periods]
    assert_empty record.errors[:work_periods]
  end

  # Edge cases with time calculations
  test "correctly handles midnight boundary (00:00)" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "0:00", "end" => "8:00" }
    ]

    assert record.valid?
  end

  test "correctly handles times with leading zeros" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "17:00" }
    ]

    assert record.valid?
  end

  test "correctly handles times without leading zeros" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "9:00", "end" => "17:00" }
    ]

    assert record.valid?
  end

  # Time conversion accuracy
  test "time_in_minutes calculation is accurate" do
    # This indirectly tests the private method through validation behavior
    record = TestRecord.new

    # 9:00 = 540 minutes, 12:00 = 720 minutes
    # These should NOT overlap (adjacent)
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "12:00", "end" => "15:00" }
    ]

    assert record.valid?, "Adjacent periods should not be considered overlapping"
  end

  test "overlap detection boundary - one minute before should not overlap" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "12:01", "end" => "15:00" }
    ]

    assert record.valid?
  end

  # Multiple errors
  test "reports all format errors for all periods" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "bad", "end" => "12:00" },
      { "start" => "09:00", "end" => "bad" },
      { "start" => "invalid", "end" => "invalid" }
    ]

    assert_not record.valid?
    assert_equal 3, record.errors[:work_periods].size
  end

  test "reports all overlap errors when multiple pairs overlap" do
    record = TestRecord.new
    record.work_periods = [
      { "start" => "09:00", "end" => "12:00" },
      { "start" => "11:00", "end" => "13:00" },  # Overlaps with first
      { "start" => "12:30", "end" => "14:00" }   # Overlaps with second
    ]

    assert_not record.valid?
    assert_operator record.errors[:work_periods].size, :>=, 2
  end
end

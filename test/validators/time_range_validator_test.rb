require "test_helper"

class TimeRangeValidatorTest < ActiveSupport::TestCase
  # Create a simple test class that uses TimeRangeValidator
  class TestRecord
    include ActiveModel::Validations

    attr_accessor :start_time, :end_time, :opening_time, :closing_time

    validates_with TimeRangeValidator, start: :start_time, end: :end_time
  end

  # Custom field names test class
  class CustomFieldRecord
    include ActiveModel::Validations

    attr_accessor :opening_time, :closing_time

    validates_with TimeRangeValidator, start: :opening_time, end: :closing_time
  end

  # Test for missing options
  test "raises ArgumentError when :start option is missing" do
    assert_raises(ArgumentError, match: /requires both :start and :end options/) do
      Class.new do
        include ActiveModel::Validations
        attr_accessor :start_time, :end_time
        validates_with TimeRangeValidator, end: :end_time
      end.new.valid?
    end
  end

  test "raises ArgumentError when :end option is missing" do
    assert_raises(ArgumentError, match: /requires both :start and :end options/) do
      Class.new do
        include ActiveModel::Validations
        attr_accessor :start_time, :end_time
        validates_with TimeRangeValidator, start: :start_time
      end.new.valid?
    end
  end

  test "raises ArgumentError when both options are missing" do
    assert_raises(ArgumentError, match: /requires both :start and :end options/) do
      Class.new do
        include ActiveModel::Validations
        attr_accessor :start_time, :end_time
        validates_with TimeRangeValidator
      end.new.valid?
    end
  end

  # Valid time ranges
  test "valid when end time is after start time with Time objects" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("09:00")
    record.end_time = Time.zone.parse("17:00")

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  test "valid when end time is after start time with DateTime objects" do
    record = TestRecord.new
    record.start_time = DateTime.parse("2025-01-01 09:00")
    record.end_time = DateTime.parse("2025-01-01 17:00")

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  test "valid with very small time difference" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("09:00:00")
    record.end_time = Time.zone.parse("09:00:01") # 1 second later

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  test "valid when times span midnight" do
    record = TestRecord.new
    record.start_time = DateTime.parse("2025-01-01 23:00")
    record.end_time = DateTime.parse("2025-01-02 01:00")

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  # Invalid time ranges
  test "invalid when end time equals start time" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("09:00")
    record.end_time = Time.zone.parse("09:00")

    assert_not record.valid?
    assert_includes record.errors[:end_time], "must be after start time"
  end

  test "invalid when end time is before start time" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("17:00")
    record.end_time = Time.zone.parse("09:00")

    assert_not record.valid?
    assert_includes record.errors[:end_time], "must be after start time"
  end

  test "invalid when times are one second apart (end before start)" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("09:00:01")
    record.end_time = Time.zone.parse("09:00:00")

    assert_not record.valid?
    assert_includes record.errors[:end_time], "must be after start time"
  end

  # Nil value handling
  test "valid when both times are nil" do
    record = TestRecord.new
    record.start_time = nil
    record.end_time = nil

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  test "valid when start time is nil" do
    record = TestRecord.new
    record.start_time = nil
    record.end_time = Time.zone.parse("17:00")

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  test "valid when end time is nil" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("09:00")
    record.end_time = nil

    assert record.valid?
    assert_empty record.errors[:end_time]
  end

  # Custom field names
  test "works with custom field names" do
    record = CustomFieldRecord.new
    record.opening_time = Time.zone.parse("09:00")
    record.closing_time = Time.zone.parse("17:00")

    assert record.valid?
    assert_empty record.errors[:closing_time]
  end

  test "error message uses humanized field name" do
    record = CustomFieldRecord.new
    record.opening_time = Time.zone.parse("17:00")
    record.closing_time = Time.zone.parse("09:00")

    assert_not record.valid?
    assert_includes record.errors[:closing_time], "must be after opening time"
  end

  test "error is added to end field not start field" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("17:00")
    record.end_time = Time.zone.parse("09:00")

    assert_not record.valid?
    assert_empty record.errors[:start_time]
    assert_not_empty record.errors[:end_time]
  end

  # Edge cases with different time types
  test "works with ActiveSupport::TimeWithZone" do
    record = TestRecord.new
    record.start_time = Time.zone.now
    record.end_time = 1.hour.from_now

    assert record.valid?
  end

  test "works with mixed time types" do
    record = TestRecord.new
    record.start_time = Time.zone.parse("2025-01-01 09:00")
    record.end_time = DateTime.parse("2025-01-01 17:00").in_time_zone

    assert record.valid?
  end

  # Multiple validations
  test "can be used with multiple field pairs in same model" do
    multi_range_class = Class.new do
      include ActiveModel::Validations

      attr_accessor :morning_start, :morning_end, :afternoon_start, :afternoon_end

      validates_with TimeRangeValidator, start: :morning_start, end: :morning_end
      validates_with TimeRangeValidator, start: :afternoon_start, end: :afternoon_end
    end

    record = multi_range_class.new
    record.morning_start = Time.zone.parse("09:00")
    record.morning_end = Time.zone.parse("12:00")
    record.afternoon_start = Time.zone.parse("13:00")
    record.afternoon_end = Time.zone.parse("17:00")

    assert record.valid?
  end

  test "validates all field pairs independently" do
    multi_range_class = Class.new do
      include ActiveModel::Validations

      attr_accessor :morning_start, :morning_end, :afternoon_start, :afternoon_end

      validates_with TimeRangeValidator, start: :morning_start, end: :morning_end
      validates_with TimeRangeValidator, start: :afternoon_start, end: :afternoon_end
    end

    record = multi_range_class.new
    record.morning_start = Time.zone.parse("12:00")
    record.morning_end = Time.zone.parse("09:00")  # Invalid
    record.afternoon_start = Time.zone.parse("13:00")
    record.afternoon_end = Time.zone.parse("17:00")  # Valid

    assert_not record.valid?
    assert_not_empty record.errors[:morning_end]
    assert_empty record.errors[:afternoon_end]
  end
end

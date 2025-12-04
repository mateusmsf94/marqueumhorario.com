require "test_helper"

class WorkScheduleCollectionTimeParsingTest < ActiveSupport::TestCase
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)
    @collection = WorkScheduleCollection.new(office: @office, provider: @provider)
  end

  test "parse_time_to_minutes converts HH:MM to minutes" do
    assert_equal 50, @collection.send(:parse_time_to_minutes, "00:50")
    assert_equal 90, @collection.send(:parse_time_to_minutes, "01:30")
    assert_equal 120, @collection.send(:parse_time_to_minutes, "02:00")
    assert_equal 10, @collection.send(:parse_time_to_minutes, "00:10")
  end

  test "parse_time_to_minutes handles legacy numeric format" do
    assert_equal 60, @collection.send(:parse_time_to_minutes, "60")
    assert_equal 15, @collection.send(:parse_time_to_minutes, "15")
  end

  test "parse_time_to_minutes handles nil and blank" do
    assert_nil @collection.send(:parse_time_to_minutes, nil)
    assert_nil @collection.send(:parse_time_to_minutes, "")
  end

  test "parse_time_to_minutes handles invalid format" do
    assert_nil @collection.send(:parse_time_to_minutes, "invalid")
    assert_nil @collection.send(:parse_time_to_minutes, "25:99")
  end
end

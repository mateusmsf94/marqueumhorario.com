require "test_helper"

class TimeFormatHelperTest < ActionView::TestCase
  include TimeFormatHelper

  test "format_minutes_as_time converts minutes to HH:MM format" do
    assert_equal "00:50", format_minutes_as_time(50)
    assert_equal "01:30", format_minutes_as_time(90)
    assert_equal "02:00", format_minutes_as_time(120)
    assert_equal "00:10", format_minutes_as_time(10)
    assert_equal "00:05", format_minutes_as_time(5)
  end

  test "format_minutes_as_time handles nil" do
    assert_equal "00:00", format_minutes_as_time(nil)
  end

  test "format_minutes_as_time handles zero" do
    assert_equal "00:00", format_minutes_as_time(0)
  end
end

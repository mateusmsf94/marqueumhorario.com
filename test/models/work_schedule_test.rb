require "test_helper"

class WorkScheduleTest < ActiveSupport::TestCase
  test "should be valid with all attributes" do
    work_schedule = WorkSchedule.new(
      day_of_week: 1,
      opening_time: "09:00",
      closing_time: "17:00",
      appointment_duration_minutes: 30,
      buffer_minutes_between_appointments: 5,
      is_active: true
    )
    assert work_schedule.valid?
  end
end

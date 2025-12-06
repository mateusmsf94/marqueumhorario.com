require "test_helper"

class WorkScheduleCalculatorTest < ActiveSupport::TestCase
  def setup
    @provider = users(:provider_john)
    @office = offices(:main_office)
    @work_schedule = work_schedules(:monday_schedule)
    @calculator = WorkScheduleCalculator.new(@work_schedule)
  end

  test "calculates total work minutes from work periods" do
    # Monday schedule: 09:00-12:00 (180 min) + 13:00-17:00 (240 min) = 420 min
    assert_equal 420, @calculator.total_work_minutes
  end

  test "returns zero for work schedule with no work periods" do
    schedule = WorkSchedule.new(
      provider: @provider,
      office: @office,
      day_of_week: 0,
      opening_time: Time.zone.parse("09:00"),
      closing_time: Time.zone.parse("17:00"),
      slot_duration_minutes: 50,
      slot_buffer_minutes: 10,
      work_periods: []
    )
    calculator = WorkScheduleCalculator.new(schedule)

    assert_equal 0, calculator.total_work_minutes
  end

  test "calculates max appointments per day" do
    # Monday schedule: 180 + 240 = 420 total minutes
    # Slot config: 60 duration + 15 buffer = 75 minutes per slot
    # 420 / 75 = 5.6, floors to 5 appointments
    assert_equal 5, @calculator.max_appointments_per_day
  end

  test "returns zero max appointments when total work minutes is zero" do
    schedule = WorkSchedule.new(
      provider: @provider,
      office: @office,
      day_of_week: 0,
      opening_time: Time.zone.parse("09:00"),
      closing_time: Time.zone.parse("17:00"),
      slot_duration_minutes: 50,
      slot_buffer_minutes: 10,
      work_periods: []
    )
    calculator = WorkScheduleCalculator.new(schedule)

    assert_equal 0, calculator.max_appointments_per_day
  end

  test "returns zero max appointments when slot duration is zero" do
    schedule = WorkSchedule.new(
      provider: @provider,
      office: @office,
      day_of_week: 0,
      opening_time: Time.zone.parse("09:00"),
      closing_time: Time.zone.parse("17:00"),
      slot_duration_minutes: 0,
      slot_buffer_minutes: 10,
      work_periods: [ { "start" => "09:00", "end" => "17:00" } ]
    )
    calculator = WorkScheduleCalculator.new(schedule)

    assert_equal 0, calculator.max_appointments_per_day
  end

  test "floors max appointments calculation" do
    # Create schedule with 125 minutes, slot of 50+10=60 minutes
    # 125 / 60 = 2.083, should floor to 2
    schedule = WorkSchedule.new(
      provider: @provider,
      office: @office,
      day_of_week: 0,
      opening_time: Time.zone.parse("09:00"),
      closing_time: Time.zone.parse("11:05"),
      slot_duration_minutes: 50,
      slot_buffer_minutes: 10,
      work_periods: [ { "start" => "09:00", "end" => "11:05" } ]
    )
    calculator = WorkScheduleCalculator.new(schedule)

    assert_equal 2, calculator.max_appointments_per_day
  end
end

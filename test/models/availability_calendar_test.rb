require "test_helper"

class AvailabilityCalendarTest < ActiveSupport::TestCase
  def setup
    @office = offices(:main_office)
  end

  test "#refresh! generates available and busy periods" do
    # 1. Fixture data
    work_schedule = work_schedules(:monday_schedule)
    appointment = appointments(:next_monday_appointment)

    # 2. Setup calendar for the week of the appointment
    appointment_date = appointment.scheduled_at.to_date
    period_start = appointment_date.beginning_of_week
    period_end = appointment_date.end_of_week

    calendar = AvailabilityCalendar.create!(
      office: @office,
      period_start: period_start,
      period_end: period_end
    )

    # 3. Run the refresh
    calendar.refresh!(work_schedules: [ work_schedule ])

    # 4. Assertions

    # Expected busy period based on the fixture
    busy_start_time = appointment.scheduled_at
    busy_end_time = busy_start_time + work_schedule.appointment_duration_minutes.minutes

    # The generator creates slots with buffer; 9:00 and 10:15 slots are blocked by the 10:00 appointment
    busy_slots = calendar.busy_periods.map { |p| Time.zone.parse(p["start_time"]).strftime("%H:%M") }.sort
    assert_equal [ "09:00", "10:15" ], busy_slots

    # Expected available periods
    # Based on the SlotGenerator logic for Monday 9-5 with 60min slots and 15min buffer
    assert_equal 4, calendar.available_periods.count

    available_times = calendar.available_periods.map { |p| Time.zone.parse(p["start_time"]).strftime("%H:%M") }.sort
    assert_equal [ "11:30", "12:45", "14:00", "15:15" ], available_times
  end
end

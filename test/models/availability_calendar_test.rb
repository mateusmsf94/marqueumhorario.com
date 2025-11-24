require "test_helper"

class AvailabilityCalendarTest < ActiveSupport::TestCase
  test "#refresh! generates available and busy periods" do
    # 1. Fixture data
    work_schedule = work_schedules(:monday_schedule)
    appointment = appointments(:next_monday_appointment)
    
    # 2. Setup calendar for the week of the appointment
    appointment_date = appointment.scheduled_at.to_date
    period_start = appointment_date.beginning_of_week
    period_end = appointment_date.end_of_week
    
    calendar = AvailabilityCalendar.create!(
      period_start: period_start,
      period_end: period_end
    )
    
    # 3. Run the refresh
    calendar.refresh!(work_schedules: [work_schedule])
    
    # 4. Assertions
    
    # Expected busy period based on the fixture
    busy_start_time = appointment.scheduled_at
    busy_end_time = busy_start_time + work_schedule.appointment_duration_minutes.minutes
    
    # The generator creates a slot from 10:15 to 11:15, which overlaps with the 10:00 appointment
    generated_busy_slot_start = appointment.scheduled_at.change(hour: 10, min: 15)
    generated_busy_slot_end = generated_busy_slot_start + work_schedule.appointment_duration_minutes.minutes
    
    assert_equal 1, calendar.busy_periods.count
    assert_equal generated_busy_slot_start.to_i, Time.parse(calendar.busy_periods.first["start_time"]).to_i
    assert_equal generated_busy_slot_end.to_i, Time.parse(calendar.busy_periods.first["end_time"]).to_i
    
    # Expected available periods
    # Based on the SlotGenerator logic for Monday 9-5 with 60min slots and 15min buffer
    assert_equal 5, calendar.available_periods.count
    
    available_times = calendar.available_periods.map { |p| Time.zone.parse(p["start_time"]).strftime("%H:%M") }.sort
    assert_equal ["09:00", "11:30", "12:45", "14:00", "15:15"], available_times
  end
end

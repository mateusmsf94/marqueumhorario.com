require "test_helper"

class TemporalScopesTest < ActiveSupport::TestCase
  def setup
    @office = offices(:main_office)
    @now = Time.current
    # Clear all existing appointments to avoid interference from fixtures
    Appointment.delete_all
    AvailabilityCalendar.delete_all
  end

  # Helper to create appointments bypassing past validation
  def create_appointment_at(scheduled_at:, **attrs)
    office = attrs.delete(:office) || @office
    apt = Appointment.new(attrs.merge(scheduled_at: 1.day.from_now, office: office))
    apt.save!(validate: false) # Skip validation initially
    apt.update_columns(scheduled_at: scheduled_at, office_id: office.id) # Update directly without validation
    apt.reload
  end

  # Test with Appointment model
  test "should provide upcoming scope for Appointment" do
    past_apt = create_appointment_at(title: "Past", scheduled_at: 1.day.ago, status: :pending, office: @office)
    future_apt1 = Appointment.create!(title: "Future 1", scheduled_at: 1.day.from_now, status: :pending, office: @office)
    future_apt2 = Appointment.create!(title: "Future 2", scheduled_at: 2.days.from_now, status: :pending, office: @office)

    upcoming = Appointment.upcoming
    assert_includes upcoming, future_apt1
    assert_includes upcoming, future_apt2
    assert_not_includes upcoming, past_apt

    # Should be ordered ascending by scheduled_at
    assert upcoming.first.scheduled_at < upcoming.second.scheduled_at, "Should be ordered ascending"
    assert_equal future_apt1.title, upcoming.first.title
    assert_equal future_apt2.title, upcoming.second.title
  end

  test "should provide past scope for Appointment" do
    past_apt1 = create_appointment_at(title: "Past 1", scheduled_at: 2.days.ago, status: :pending, office: @office)
    past_apt2 = create_appointment_at(title: "Past 2", scheduled_at: 1.day.ago, status: :pending, office: @office)
    future_apt = Appointment.create!(title: "Future", scheduled_at: 1.day.from_now, status: :pending, office: @office)

    past = Appointment.past
    assert_includes past, past_apt1
    assert_includes past, past_apt2
    assert_not_includes past, future_apt

    # Should be ordered descending (most recent first)
    assert past.first.scheduled_at > past.second.scheduled_at, "Should be ordered descending"
    assert_equal past_apt2.title, past.first.title
    assert_equal past_apt1.title, past.second.title
  end

  test "should provide today scope for Appointment" do
    past_apt = create_appointment_at(title: "Yesterday", scheduled_at: 1.day.ago, status: :pending, office: @office)
    today_apt = Appointment.create!(title: "Today", scheduled_at: Time.current + 1.hour, status: :pending, office: @office)
    future_apt = Appointment.create!(title: "Tomorrow", scheduled_at: 1.day.from_now, status: :pending, office: @office)

    today_appointments = Appointment.today
    assert_includes today_appointments, today_apt
    assert_not_includes today_appointments, past_apt
    assert_not_includes today_appointments, future_apt
  end

  test "should provide between scope for Appointment" do
    before_range = create_appointment_at(title: "Before", scheduled_at: 5.days.ago, status: :pending, office: @office)
    in_range1 = create_appointment_at(title: "In Range 1", scheduled_at: 2.days.ago, status: :pending, office: @office)
    in_range2 = create_appointment_at(title: "In Range 2", scheduled_at: 1.day.ago, status: :pending, office: @office)
    after_range = Appointment.create!(title: "After", scheduled_at: 1.day.from_now, status: :pending, office: @office)

    start_time = 3.days.ago
    end_time = Time.current

    between = Appointment.between(start_time, end_time)
    assert_includes between, in_range1
    assert_includes between, in_range2
    assert_not_includes between, before_range
    assert_not_includes between, after_range
  end

  test "should provide on_date scope for Appointment" do
    yesterday = create_appointment_at(title: "Yesterday", scheduled_at: 1.day.ago.beginning_of_day, status: :pending, office: @office)
    today_morning = create_appointment_at(title: "Today Morning", scheduled_at: Time.current.beginning_of_day + 9.hours, status: :pending, office: @office)
    today_evening = create_appointment_at(title: "Today Evening", scheduled_at: Time.current.beginning_of_day + 18.hours, status: :pending, office: @office)
    tomorrow = create_appointment_at(title: "Tomorrow", scheduled_at: 1.day.from_now, status: :pending, office: @office)

    today_appointments = Appointment.on_date(Time.current)
    assert_includes today_appointments, today_morning
    assert_includes today_appointments, today_evening
    assert_not_includes today_appointments, yesterday
    assert_not_includes today_appointments, tomorrow
  end

  # Test with AvailabilityCalendar model
  test "should provide upcoming scope for AvailabilityCalendar" do
    past_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 2.days.ago,
      period_end: 1.day.ago,
      available_periods: [],
      busy_periods: []
    )
    future_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 1.day.from_now,
      period_end: 2.days.from_now,
      available_periods: [],
      busy_periods: []
    )

    upcoming = AvailabilityCalendar.upcoming
    assert_includes upcoming, future_calendar
    assert_not_includes upcoming, past_calendar
  end

  test "should provide past scope for AvailabilityCalendar" do
    past_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 2.days.ago,
      period_end: 1.day.ago,
      available_periods: [],
      busy_periods: []
    )
    future_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 1.day.from_now,
      period_end: 2.days.from_now,
      available_periods: [],
      busy_periods: []
    )

    past = AvailabilityCalendar.past
    assert_includes past, past_calendar
    assert_not_includes past, future_calendar
  end

  test "should provide today scope for AvailabilityCalendar" do
    past_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 2.days.ago,
      period_end: 1.day.ago,
      available_periods: [],
      busy_periods: []
    )
    today_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: Time.current.beginning_of_day,
      period_end: Time.current.end_of_day,
      available_periods: [],
      busy_periods: []
    )
    future_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 1.day.from_now,
      period_end: 2.days.from_now,
      available_periods: [],
      busy_periods: []
    )

    today_calendars = AvailabilityCalendar.today
    assert_includes today_calendars, today_calendar
    assert_not_includes today_calendars, past_calendar
    assert_not_includes today_calendars, future_calendar
  end

  test "should provide between scope for AvailabilityCalendar" do
    before_range = AvailabilityCalendar.create!(office: @office,
      period_start: 10.days.ago,
      period_end: 9.days.ago,
      available_periods: [],
      busy_periods: []
    )
    in_range = AvailabilityCalendar.create!(office: @office,
      period_start: 2.days.ago,
      period_end: 1.day.ago,
      available_periods: [],
      busy_periods: []
    )
    after_range = AvailabilityCalendar.create!(office: @office,
      period_start: 5.days.from_now,
      period_end: 6.days.from_now,
      available_periods: [],
      busy_periods: []
    )

    start_time = 3.days.ago
    end_time = Time.current

    between = AvailabilityCalendar.between(start_time, end_time)
    assert_includes between, in_range
    assert_not_includes between, before_range
    assert_not_includes between, after_range
  end

  test "should provide on_date scope for AvailabilityCalendar" do
    yesterday_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 1.day.ago.beginning_of_day,
      period_end: 1.day.ago.end_of_day,
      available_periods: [],
      busy_periods: []
    )
    today_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: Time.current.beginning_of_day,
      period_end: Time.current.end_of_day,
      available_periods: [],
      busy_periods: []
    )
    tomorrow_calendar = AvailabilityCalendar.create!(office: @office,
      period_start: 1.day.from_now.beginning_of_day,
      period_end: 1.day.from_now.end_of_day,
      available_periods: [],
      busy_periods: []
    )

    today_calendars = AvailabilityCalendar.on_date(Time.current)
    assert_includes today_calendars, today_calendar
    assert_not_includes today_calendars, yesterday_calendar
    assert_not_includes today_calendars, tomorrow_calendar
  end

  # Edge cases
  test "should handle boundary conditions for upcoming scope" do
    # Appointment at current time + 1 second to ensure it's in the future
    exact_now = Appointment.create!(title: "Now", scheduled_at: Time.current + 1.second, status: :pending, office: @office)

    upcoming = Appointment.upcoming
    assert_includes upcoming, exact_now, "Should include appointment at exact current time"
  end

  test "should handle empty result sets" do
    # Clear all appointments
    Appointment.destroy_all

    assert_empty Appointment.upcoming
    assert_empty Appointment.past
    assert_empty Appointment.today
    assert_empty Appointment.between(1.day.ago, 1.day.from_now)
  end

  test "should be chainable with other scopes" do
    past_pending = create_appointment_at(title: "Past Pending", scheduled_at: 1.day.ago, status: :pending, office: @office)
    past_confirmed = create_appointment_at(title: "Past Confirmed", scheduled_at: 2.days.ago, status: :confirmed)
    future_pending = Appointment.create!(title: "Future Pending", scheduled_at: 1.day.from_now, status: :pending, office: @office)

    # Chain temporal scope with status scope
    past_pending_appointments = Appointment.past.by_status(:pending)
    assert_includes past_pending_appointments, past_pending
    assert_not_includes past_pending_appointments, past_confirmed
    assert_not_includes past_pending_appointments, future_pending
  end
end

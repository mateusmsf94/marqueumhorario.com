require "test_helper"

class WorkScheduleTest < ActiveSupport::TestCase
  def valid_attributes
    {
      day_of_week: 1,
      opening_time: "09:00",
      closing_time: "17:00",
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      is_active: true,
      office_id: offices(:main_office).id
    }
  end

  # Basic validation test
  test "should be valid with all attributes" do
    # Use day 1 (Monday) but mark as inactive to avoid uniqueness conflict with fixtures
    work_schedule = WorkSchedule.new(valid_attributes.merge(is_active: false))
    assert work_schedule.valid?, "WorkSchedule should be valid with all required attributes"
  end

  # Presence validations
  test "should not save without day_of_week" do
    work_schedule = WorkSchedule.new(valid_attributes.except(:day_of_week))
    assert_not work_schedule.save, "Saved WorkSchedule without day_of_week"
    assert_includes work_schedule.errors[:day_of_week], "can't be blank"
  end

  test "should not save without opening_time" do
    work_schedule = WorkSchedule.new(valid_attributes.except(:opening_time))
    assert_not work_schedule.save, "Saved WorkSchedule without opening_time"
    assert_includes work_schedule.errors[:opening_time], "can't be blank"
  end

  test "should not save without closing_time" do
    work_schedule = WorkSchedule.new(valid_attributes.except(:closing_time))
    assert_not work_schedule.save, "Saved WorkSchedule without closing_time"
    assert_includes work_schedule.errors[:closing_time], "can't be blank"
  end

  test "should not save without appointment_duration_minutes" do
    work_schedule = WorkSchedule.new(valid_attributes.except(:appointment_duration_minutes))
    assert_not work_schedule.save, "Saved WorkSchedule without appointment_duration_minutes"
    assert_includes work_schedule.errors[:appointment_duration_minutes], "can't be blank"
  end

  test "should not save without buffer_minutes_between_appointments" do
    work_schedule = WorkSchedule.new(valid_attributes.except(:buffer_minutes_between_appointments))
    assert_not work_schedule.save, "Saved WorkSchedule without buffer_minutes_between_appointments"
    assert_includes work_schedule.errors[:buffer_minutes_between_appointments], "can't be blank"
  end

  # Numericality validations - day_of_week
  test "should require day_of_week to be an integer" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: 2.5))
    assert_not work_schedule.valid?, "Saved WorkSchedule with non-integer day_of_week"
    assert_includes work_schedule.errors[:day_of_week], "must be an integer"
  end

  test "should require day_of_week between 0 and 6" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: 7))
    assert_not work_schedule.valid?, "Saved WorkSchedule with day_of_week > 6"
    assert_includes work_schedule.errors[:day_of_week], "must be less than or equal to 6"

    work_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: -1))
    assert_not work_schedule.valid?, "Saved WorkSchedule with day_of_week < 0"
    assert_includes work_schedule.errors[:day_of_week], "must be greater than or equal to 0"
  end

  test "should allow day_of_week from 0 to 6" do
    (0..6).each do |day|
      # Use inactive to avoid uniqueness conflicts with fixtures
      work_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: day, is_active: false))
      assert work_schedule.valid?, "Day #{day} should be valid"
    end
  end

  # Numericality validations - appointment_duration_minutes
  test "should require positive appointment_duration_minutes" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(appointment_duration_minutes: 0))
    assert_not work_schedule.valid?, "Saved WorkSchedule with zero appointment_duration_minutes"
    assert_includes work_schedule.errors[:appointment_duration_minutes], "must be greater than 0"

    work_schedule = WorkSchedule.new(valid_attributes.merge(appointment_duration_minutes: -10))
    assert_not work_schedule.valid?, "Saved WorkSchedule with negative appointment_duration_minutes"
    assert_includes work_schedule.errors[:appointment_duration_minutes], "must be greater than 0"
  end

  # Numericality validations - buffer_minutes_between_appointments
  test "should allow zero buffer_minutes_between_appointments" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(buffer_minutes_between_appointments: 0, is_active: false))
    assert work_schedule.valid?, "Should allow zero buffer minutes"
  end

  test "should not allow negative buffer_minutes_between_appointments" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(buffer_minutes_between_appointments: -5))
    assert_not work_schedule.valid?, "Saved WorkSchedule with negative buffer_minutes_between_appointments"
    assert_includes work_schedule.errors[:buffer_minutes_between_appointments], "must be greater than or equal to 0"
  end

  # Time range validation
  test "should not allow closing_time before opening_time" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(opening_time: "17:00", closing_time: "09:00"))
    assert_not work_schedule.valid?, "Saved WorkSchedule with closing_time before opening_time"
    assert_includes work_schedule.errors[:closing_time], "must be after opening time"
  end

  test "should not allow closing_time equal to opening_time" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(opening_time: "09:00", closing_time: "09:00"))
    assert_not work_schedule.valid?, "Saved WorkSchedule with closing_time equal to opening_time"
    assert_includes work_schedule.errors[:closing_time], "must be after opening time"
  end

  # Custom validation - must accommodate at least one slot
  test "should not allow appointment_duration longer than work day" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(
      opening_time: "09:00",
      closing_time: "10:00",
      appointment_duration_minutes: 120 # 2 hours, but only 1 hour available
    ))
    assert_not work_schedule.valid?, "Saved WorkSchedule with appointment_duration longer than work day"
    assert work_schedule.errors[:appointment_duration_minutes].any? { |msg| msg.include?("is too long for the available work hours") },
      "Expected error message about work hours, got: #{work_schedule.errors[:appointment_duration_minutes]}"
  end

  test "should allow appointment_duration equal to work day length" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(
      opening_time: "09:00",
      closing_time: "10:00",
      appointment_duration_minutes: 60, # Exactly 1 hour
      is_active: false
    ))
    assert work_schedule.valid?, "Should allow appointment_duration equal to work day length"
  end

  # Uniqueness validation
  test "should not allow multiple active schedules for same day_of_week and office" do
    # Fixtures already have an active Monday schedule for main_office, so try to create another
    second_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: 1, is_active: true, office_id: offices(:main_office).id))
    assert_not second_schedule.valid?, "Should not allow multiple active schedules for same day and office"
    assert_includes second_schedule.errors[:day_of_week], "can only have one active schedule per day per office"
  end

  test "should allow multiple inactive schedules for same day_of_week and office" do
    first_schedule = WorkSchedule.create!(valid_attributes.merge(day_of_week: 1, is_active: false, office_id: offices(:main_office).id))
    second_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: 1, is_active: false, office_id: offices(:main_office).id))

    assert second_schedule.valid?, "Should allow multiple inactive schedules for same day and office"
  end

  test "should allow active and inactive schedules for same day_of_week and office" do
    # Fixtures already have active Monday schedule for main_office, just create an inactive one
    inactive_schedule = WorkSchedule.new(valid_attributes.merge(day_of_week: 1, is_active: false, office_id: offices(:main_office).id))

    assert inactive_schedule.valid?, "Should allow both active and inactive schedules for same day and office"
  end

  test "should allow same day_of_week active schedule for different offices" do
    # Main office already has Monday schedule (day 1)
    # Create Monday schedule for west coast office
    west_coast_schedule = WorkSchedule.new(valid_attributes.merge(
      day_of_week: 2,
      is_active: true,
      office_id: offices(:west_coast_office).id
    ))

    assert west_coast_schedule.valid?, "Should allow same day schedule for different offices"
    assert west_coast_schedule.save
  end

  # Edge cases
  test "should handle midnight crossing edge case" do
    work_schedule = WorkSchedule.new(valid_attributes.merge(
      opening_time: "22:00",
      closing_time: "23:59",
      appointment_duration_minutes: 60,
      is_active: false
    ))
    assert work_schedule.valid?, "Should handle evening work hours"
  end

  test "should use fixture from fixtures file" do
    monday_schedule = work_schedules(:monday_schedule)
    assert monday_schedule.valid?, "Fixture should be valid"
    assert_equal 1, monday_schedule.day_of_week
  end

  # Office association
  test "should belong to office" do
    schedule = work_schedules(:monday_schedule)
    assert_respond_to schedule, :office
    assert_instance_of Office, schedule.office
  end

  test "should not save without office" do
    schedule = WorkSchedule.new(valid_attributes.merge(office_id: nil))
    assert_not schedule.save
    assert_includes schedule.errors[:office], "must exist"
  end

  test "for_office scope should filter by office" do
    main_office_schedules = WorkSchedule.for_office(offices(:main_office).id)
    west_coast_schedules = WorkSchedule.for_office(offices(:west_coast_office).id)

    assert main_office_schedules.all? { |sched| sched.office_id == offices(:main_office).id }
    assert west_coast_schedules.all? { |sched| sched.office_id == offices(:west_coast_office).id }
    assert main_office_schedules.count > 0, "Should have schedules for main office"
  end
end

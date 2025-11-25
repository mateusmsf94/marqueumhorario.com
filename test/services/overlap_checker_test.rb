require "test_helper"

class OverlapCheckerTest < ActiveSupport::TestCase
  def setup
    @duration = 60.minutes
    @base_time = (Time.current + 1.day).beginning_of_day + 10.hours # 10:00 AM tomorrow to avoid "past" validation
    @office = offices(:main_office)
  end

  # Basic overlap detection
  test "should detect overlap when appointment is within the time range" do
    appointment = Appointment.create!(
      title: "Test Appointment",
      scheduled_at: @base_time + 30.minutes, # 10:30 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect overlap"
  end

  test "should not detect overlap when appointment is before the time range" do
    appointment = Appointment.create!(
      title: "Past Appointment",
      scheduled_at: @base_time - 2.hours, # 8:00 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert_not checker.any_overlap?(@base_time, @base_time + @duration), "Should not detect overlap"
  end

  test "should not detect overlap when appointment is after the time range" do
    appointment = Appointment.create!(
      title: "Future Appointment",
      scheduled_at: @base_time + 2.hours, # 12:00 PM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert_not checker.any_overlap?(@base_time, @base_time + @duration), "Should not detect overlap"
  end

  # Edge cases - boundary conditions
  test "should detect overlap when appointment starts exactly at range start" do
    appointment = Appointment.create!(
      title: "Exact Start",
      scheduled_at: @base_time, # Exactly 10:00 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect overlap at boundary"
  end

  test "should not detect overlap when appointment ends exactly at range start" do
    appointment = Appointment.create!(
      title: "Just Before",
      scheduled_at: @base_time - @duration, # Ends exactly at 10:00 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert_not checker.any_overlap?(@base_time, @base_time + @duration), "Should not detect overlap when just touching"
  end

  test "should detect overlap when appointment starts just before range end" do
    appointment = Appointment.create!(
      title: "Starts Near End",
      scheduled_at: @base_time + @duration - 1.minute, # Starts at 10:59 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect overlap near end"
  end

  # Multiple appointments
  test "should detect overlap with multiple appointments when one overlaps" do
    appointments = [
      Appointment.create!(title: "Before", scheduled_at: @base_time - 2.hours, status: :pending, office: @office),
      Appointment.create!(title: "During", scheduled_at: @base_time + 15.minutes, status: :pending, office: @office), # Overlaps!
      Appointment.create!(title: "After", scheduled_at: @base_time + 3.hours, status: :pending, office: @office)
    ]

    checker = OverlapChecker.new(appointments, duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect overlap with multiple appointments"
  end

  test "should not detect overlap with multiple appointments when none overlap" do
    appointments = [
      Appointment.create!(title: "Before", scheduled_at: @base_time - 2.hours, status: :pending, office: @office),
      Appointment.create!(title: "After", scheduled_at: @base_time + 3.hours, status: :pending, office: @office)
    ]

    checker = OverlapChecker.new(appointments, duration: @duration)
    assert_not checker.any_overlap?(@base_time, @base_time + @duration), "Should not detect overlap"
  end

  # find_overlapping method
  test "should find all overlapping appointments" do
    overlapping1 = Appointment.create!(title: "Overlap 1", scheduled_at: @base_time + 15.minutes, status: :pending, office: @office)
    overlapping2 = Appointment.create!(title: "Overlap 2", scheduled_at: @base_time + 45.minutes, status: :pending, office: @office)
    non_overlapping = Appointment.create!(title: "No Overlap", scheduled_at: @base_time + 3.hours, status: :pending, office: @office)

    checker = OverlapChecker.new([ overlapping1, overlapping2, non_overlapping ], duration: @duration)
    overlapping = checker.find_overlapping(@base_time, @base_time + @duration)

    assert_equal 2, overlapping.size, "Should find exactly 2 overlapping appointments"
    assert_includes overlapping, overlapping1
    assert_includes overlapping, overlapping2
    assert_not_includes overlapping, non_overlapping
  end

  test "should return empty array when no appointments overlap" do
    appointment = Appointment.create!(title: "No Overlap", scheduled_at: @base_time + 3.hours, status: :pending, office: @office)

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    overlapping = checker.find_overlapping(@base_time, @base_time + @duration)

    assert_empty overlapping, "Should return empty array"
  end

  # Duration parameter
  test "should use provided duration for overlap calculation" do
    # Appointment at 10:00 AM with 30 min duration (ends at 10:30 AM)
    appointment = Appointment.create!(title: "Short", scheduled_at: @base_time, status: :pending, office: @office)

    # Check 11:00-12:00 slot with 30 min duration
    checker = OverlapChecker.new([ appointment ], duration: 30.minutes)
    assert_not checker.any_overlap?(@base_time + 1.hour, @base_time + 2.hours), "Should not overlap with 30 min duration"

    # Check 10:15-11:15 slot with 30 min duration
    assert checker.any_overlap?(@base_time + 15.minutes, @base_time + 1.hour + 15.minutes), "Should overlap with 30 min duration"
  end

  test "should use default duration when none provided" do
    appointment = Appointment.create!(title: "Default Duration", scheduled_at: @base_time, status: :pending, office: @office)

    # Without providing duration, it should use default (60 minutes from the service)
    checker = OverlapChecker.new([ appointment ])
    assert checker.any_overlap?(@base_time, @base_time + 1.hour), "Should use default duration"
  end

  # Empty appointments array
  test "should not detect overlap with empty appointments array" do
    checker = OverlapChecker.new([], duration: @duration)
    assert_not checker.any_overlap?(@base_time, @base_time + @duration), "Should not detect overlap with empty array"
  end

  test "should return empty array when finding overlaps with no appointments" do
    checker = OverlapChecker.new([], duration: @duration)
    assert_empty checker.find_overlapping(@base_time, @base_time + @duration), "Should return empty array"
  end

  # Integration with ActiveRecord::Relation
  test "should work with ActiveRecord::Relation" do
    # Create appointments
    Appointment.create!(title: "Overlap", scheduled_at: @base_time + 30.minutes, status: :pending, office: @office)
    Appointment.create!(title: "No Overlap", scheduled_at: @base_time + 5.hours, status: :pending, office: @office)

    # Use ActiveRecord::Relation instead of array
    appointments = Appointment.where("scheduled_at >= ?", @base_time)
    checker = OverlapChecker.new(appointments, duration: @duration)

    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should work with ActiveRecord::Relation"
  end

  # Partial overlaps
  test "should detect overlap when appointment starts before and ends during range" do
    appointment = Appointment.create!(
      title: "Partial Start",
      scheduled_at: @base_time - 30.minutes, # Starts at 9:30 AM, ends at 10:30 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect partial overlap at start"
  end

  test "should detect overlap when appointment starts during and ends after range" do
    appointment = Appointment.create!(
      title: "Partial End",
      scheduled_at: @base_time + 30.minutes, # Starts at 10:30 AM, ends at 11:30 AM
      status: :pending,
      office: @office
    )

    checker = OverlapChecker.new([ appointment ], duration: @duration)
    assert checker.any_overlap?(@base_time, @base_time + @duration), "Should detect partial overlap at end"
  end

  test "should detect overlap when appointment completely contains the range" do
    appointment = Appointment.create!(
      title: "Contains Range",
      scheduled_at: @base_time - 30.minutes, # Starts at 9:30 AM, ends at 10:30 AM with @duration
      status: :pending,
      office: @office
    )

    # Check a smaller range that's completely within the appointment
    checker = OverlapChecker.new([ appointment ], duration: 2.hours) # Appointment runs from 9:30 to 11:30
    assert checker.any_overlap?(@base_time, @base_time + 30.minutes), "Should detect when appointment contains range"
  end
end

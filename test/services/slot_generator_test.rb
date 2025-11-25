require "test_helper"

class SlotGeneratorTest < ActiveSupport::TestCase
  setup do
    @main_office = offices(:main_office)
    @west_coast_office = offices(:west_coast_office)
    @monday_schedule = work_schedules(:monday_schedule)
    @west_coast_monday_schedule = work_schedules(:west_coast_monday_schedule)
    @start_date = Date.today.next_occurring(:monday)
    @end_date = @start_date
  end

  test "should generate slots for office" do
    generator = SlotGenerator.new([ @monday_schedule ], Appointment.none, office_id: @main_office.id)
    slots = generator.call(@start_date, @end_date)

    assert slots.any?, "Should generate slots"
    assert slots.all? { |slot| slot.office_id == @main_office.id }, "All slots should belong to main office"
  end

  test "should only use work schedules for specified office" do
    # Create generator with both office schedules but specify main_office
    generator = SlotGenerator.new(
      [ @monday_schedule, @west_coast_monday_schedule ],
      Appointment.none,
      office_id: @main_office.id
    )

    slots = generator.call(@start_date, @end_date)

    # Should only generate slots for main_office schedule (9am-5pm, 60min slots)
    assert slots.all? { |slot| slot.office_id == @main_office.id }, "All slots should be for main office"
    # Main office opens at 9am
    first_slot = slots.first
    assert_equal 9, first_slot.start_time.hour, "First slot should start at 9am (main office hours)"
  end

  test "should mark slots as busy when appointments exist for office" do
    # Create appointment for main office on Monday at 9am (first slot)
    appointment = Appointment.create!(
      title: "Test Appointment",
      scheduled_at: @start_date.to_datetime.change(hour: 9, min: 0),
      office: @main_office,
      status: :confirmed
    )

    generator = SlotGenerator.new([ @monday_schedule ], [ appointment ], office_id: @main_office.id)
    slots = generator.call(@start_date, @end_date)

    # Find the 9am slot (first slot of the day)
    busy_slot = slots.find { |s| s.start_time.hour == 9 && s.start_time.min == 0 }
    assert_equal "busy", busy_slot.status, "9am slot should be marked as busy"
  end

  test "should not mark slots as busy for appointments in different office" do
    # Create appointment for west coast office at 9am
    appointment = Appointment.create!(
      title: "West Coast Appointment",
      scheduled_at: @start_date.to_datetime.change(hour: 9, min: 0),
      office: @west_coast_office,
      status: :confirmed
    )

    # Generate slots for main office
    generator = SlotGenerator.new([ @monday_schedule ], [ appointment ], office_id: @main_office.id)
    slots = generator.call(@start_date, @end_date)

    # 9am slot for main office should still be available (appointment is in different office)
    slot_at_9am = slots.find { |s| s.start_time.hour == 9 && s.start_time.min == 0 }
    assert_equal "available", slot_at_9am.status, "Main office 9am slot should be available (appointment is in different office)"
  end

  test "should handle empty work schedules" do
    generator = SlotGenerator.new([], Appointment.none, office_id: @main_office.id)
    slots = generator.call(@start_date, @end_date)

    assert_empty slots, "Should return empty array for no schedules"
  end

  test "should filter appointments by office in check_availability" do
    # Create appointments in both offices at 9am
    main_apt = Appointment.create!(
      title: "Main Office Appointment",
      scheduled_at: @start_date.to_datetime.change(hour: 9, min: 0),
      office: @main_office,
      status: :confirmed
    )

    west_coast_apt = Appointment.create!(
      title: "West Coast Appointment",
      scheduled_at: @start_date.to_datetime.change(hour: 9, min: 0),
      office: @west_coast_office,
      status: :confirmed
    )

    # Generate slots for main office
    main_generator = SlotGenerator.new([ @monday_schedule ], [ main_apt, west_coast_apt ], office_id: @main_office.id)
    main_slots = main_generator.call(@start_date, @end_date)

    # Main office 9am should be busy (has appointment)
    main_9am = main_slots.find { |s| s.start_time.hour == 9 && s.start_time.min == 0 }
    assert_equal "busy", main_9am.status

    # Generate slots for west coast office (starts at 8am)
    west_generator = SlotGenerator.new([ @west_coast_monday_schedule ], [ main_apt, west_coast_apt ], office_id: @west_coast_office.id)
    west_slots = west_generator.call(@start_date, @end_date)

    # West coast 9am slot: 8am start + 60min + 15min buffer = first slot ends at 9:15, second slot starts at 9:15
    # So 9am appointment would make the 8am slot busy
    west_8am = west_slots.find { |s| s.start_time.hour == 8 && s.start_time.min == 0 }
    assert_equal "busy", west_8am.status, "West coast 8am slot should be busy (appointment at 9am overlaps)"
  end
end

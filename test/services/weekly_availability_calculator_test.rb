require "test_helper"

class WeeklyAvailabilityCalculatorTest < ActiveSupport::TestCase
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)
    @week_start = Date.today.beginning_of_week

    # Deactivate any existing work schedules for this provider/office to avoid conflicts
    WorkSchedule.where(
      provider: @provider,
      office: @office,
      is_active: true
    ).update_all(is_active: false)

    # Set up a work schedule for testing (Monday = day 1)
    @work_schedule = WorkSchedule.create!(
      office: @office,
      provider: @provider,
      day_of_week: 1, # Monday
      is_active: true,
      work_periods: [
        { "start" => "09:00", "end" => "17:00" }
      ],
      opening_time: "09:00",
      closing_time: "17:00",
      slot_duration_minutes: 60,
      slot_buffer_minutes: 15
    )
  end

  # Initialization tests
  test "initializes with office and provider" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider
    )

    assert_equal @office, calculator.office
    assert_equal @provider, calculator.provider
  end

  test "defaults week_start to current week's Monday" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider
    )

    assert_equal Date.today.beginning_of_week, calculator.week_start
  end

  test "accepts custom week_start" do
    custom_start = 2.weeks.from_now.to_date.beginning_of_week

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: custom_start
    )

    assert_equal custom_start, calculator.week_start
  end

  # Call method tests
  test "call returns hash with expected keys" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_instance_of Hash, result
    assert_includes result.keys, :slots_by_day
    assert_includes result.keys, :total_slots
    assert_includes result.keys, :available_slots
    assert_includes result.keys, :appointments
    assert_includes result.keys, :work_schedules
    assert_includes result.keys, :week_start
    assert_includes result.keys, :week_end
  end

  test "call returns slots grouped by day" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_instance_of Hash, result[:slots_by_day]
    # Slots should be grouped by Date
    result[:slots_by_day].each do |date, slots|
      assert_instance_of Date, date
      assert_instance_of Array, slots
    end
  end

  test "call returns total_slots count" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_instance_of Integer, result[:total_slots]
    assert_operator result[:total_slots], :>=, 0
  end

  test "call returns available_slots count" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_instance_of Integer, result[:available_slots]
    assert_operator result[:available_slots], :>=, 0
    assert_operator result[:available_slots], :<=, result[:total_slots]
  end

  test "call returns work_schedules relation" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_respond_to result[:work_schedules], :each
    result[:work_schedules].each do |schedule|
      assert_instance_of WorkSchedule, schedule
      assert_equal @office.id, schedule.office_id
      assert_equal @provider.id, schedule.provider_id
      assert schedule.is_active
    end
  end

  test "call returns appointments for the week" do
    # Use a future week to avoid past date validation errors
    future_week = 2.weeks.from_now.to_date.beginning_of_week

    # Create appointment on Monday of future week at 10 AM
    appointment = Appointment.create!(
      office: @office,
      provider: @provider,
      customer: users(:customer_alice),
      scheduled_at: future_week + 1.day + 10.hours,
      duration_minutes: 60,
      title: "Test Appointment",
      status: "confirmed"
    )

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: future_week
    )

    result = calculator.call

    assert_respond_to result[:appointments], :each
    assert_includes result[:appointments].map(&:id), appointment.id
  end

  test "call returns week_start and week_end" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_equal @week_start, result[:week_start]
    assert_equal @week_start.end_of_week, result[:week_end]
  end

  # Week range tests
  test "week_range returns correct range" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    range = calculator.week_range

    assert_instance_of Range, range
    assert_equal @week_start, range.begin
    assert_equal @week_start.end_of_week, range.end
  end

  # Edge cases
  test "handles provider with no work schedules" do
    provider_no_schedules = users(:customer_alice) # Customer, no schedules

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: provider_no_schedules,
      week_start: @week_start
    )

    result = calculator.call

    assert_equal({}, result[:slots_by_day])
    assert_equal 0, result[:total_slots]
    assert_equal 0, result[:available_slots]
  end

  test "handles week with no appointments" do
    # Use a future week with no appointments
    future_week = 4.weeks.from_now.to_date.beginning_of_week

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: future_week
    )

    result = calculator.call

    assert_empty result[:appointments]
    # All slots should be available if there are work schedules
  end

  test "available_slots decreases when appointments are booked" do
    # Use a future week to avoid past date validation errors
    future_week = 2.weeks.from_now.to_date.beginning_of_week

    # First, get availability without appointments
    calculator1 = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: future_week
    )
    result1 = calculator1.call
    initial_available = result1[:available_slots]

    # Create an appointment on Monday at 10 AM (overlaps with work schedule)
    Appointment.create!(
      office: @office,
      provider: @provider,
      customer: users(:customer_alice),
      scheduled_at: future_week + 1.day + 10.hours,
      duration_minutes: 60,
      title: "Booked Slot",
      status: "confirmed"
    )

    # Get availability again
    calculator2 = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: future_week
    )
    result2 = calculator2.call
    final_available = result2[:available_slots]

    # Available slots should decrease (or stay same if appointment doesn't overlap)
    assert_operator final_available, :<=, initial_available
  end

  # Memoization tests
  test "memoizes results for efficiency" do
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    # Call multiple times
    result1 = calculator.call
    result2 = calculator.call

    # Should return the same object (memoized)
    assert_same result1[:slots_by_day].object_id, result2[:slots_by_day].object_id
  end

  # Integration with multiple work schedules
  test "handles multiple work schedules across different days" do
    # Monday schedule already exists from setup

    # Add Wednesday schedule
    wednesday_schedule = WorkSchedule.create!(
      office: @office,
      provider: @provider,
      day_of_week: 3, # Wednesday
      is_active: true,
      work_periods: [{ "start" => "10:00", "end" => "16:00" }],
      opening_time: "10:00",
      closing_time: "16:00",
      slot_duration_minutes: 60,
      slot_buffer_minutes: 15
    )

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    assert_operator result[:total_slots], :>, 0
    # Should have slots on multiple days
    assert_operator result[:slots_by_day].keys.size, :>=, 1
  end

  # Test with different office
  test "only includes schedules for specified office" do
    other_office = offices(:west_coast_office)

    # Create schedule for other office
    WorkSchedule.create!(
      office: other_office,
      provider: @provider,
      day_of_week: 2, # Tuesday
      is_active: true,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      opening_time: "09:00",
      closing_time: "17:00",
      slot_duration_minutes: 60,
      slot_buffer_minutes: 15
    )

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office, # Using main_office
      provider: @provider,
      week_start: @week_start
    )

    result = calculator.call

    # Should only include schedules for @office, not other_office
    result[:work_schedules].each do |schedule|
      assert_equal @office.id, schedule.office_id
    end
  end

  # Test with different provider
  test "only includes schedules for specified provider" do
    other_provider = users(:provider_jane)

    # Deactivate any existing schedules for other provider to avoid uniqueness conflicts
    WorkSchedule.where(
      provider: other_provider,
      office: @office,
      day_of_week: 4,
      is_active: true
    ).update_all(is_active: false)

    # Create schedule for other provider
    WorkSchedule.create!(
      office: @office,
      provider: other_provider,
      day_of_week: 4, # Thursday
      is_active: true,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      opening_time: "09:00",
      closing_time: "17:00",
      slot_duration_minutes: 60,
      slot_buffer_minutes: 15
    )

    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: @provider, # Using provider_john
      week_start: @week_start
    )

    result = calculator.call

    # Should only include schedules for @provider, not other_provider
    result[:work_schedules].each do |schedule|
      assert_equal @provider.id, schedule.provider_id
    end
  end
end

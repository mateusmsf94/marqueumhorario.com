require "test_helper"

class AvailabilityServiceTest < ActiveSupport::TestCase
  def setup
    @provider = users(:provider_john)
    @office = offices(:main_office)
    # Use a Monday for testing (work schedule: 09:00-12:00, 13:00-17:00)
    @test_date = Date.today.next_occurring(:monday)

    # Clean up any existing appointments for this test date
    # (fixtures may have appointments on this date)
    Appointment.where(
      provider: @provider,
      office: @office,
      scheduled_at: @test_date.beginning_of_day..@test_date.end_of_day
    ).destroy_all
  end

  test "returns empty array when no work schedule exists" do
    # Use a provider without schedules at this office
    service = AvailabilityService.new(
      provider: users(:provider_jane),
      office: offices(:west_coast_office),
      date: @test_date
    )

    assert_equal [], service.available_periods
  end

  test "returns work periods when no appointments exist" do
    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # Monday schedule has lunch break: 09:00-12:00, 13:00-17:00
    assert_equal 2, periods.length

    # Check first period (morning)
    assert_equal 9, periods[0].start_time.hour
    assert_equal 0, periods[0].start_time.min
    assert_equal 12, periods[0].end_time.hour
    assert_equal 0, periods[0].end_time.min

    # Check second period (afternoon)
    assert_equal 13, periods[1].start_time.hour
    assert_equal 0, periods[1].start_time.min
    assert_equal 17, periods[1].end_time.hour
    assert_equal 0, periods[1].end_time.min
  end

  test "subtracts appointment from beginning of period" do
    # Create appointment at 09:00 (duration: 60 min + buffer: 15 min = 75 min total)
    appointment = Appointment.create!(
      title: "Morning appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # First period should now be 10:15-12:00 (appointment blocks 09:00-10:15)
    # Second period unchanged: 13:00-17:00
    assert_equal 2, periods.length
    assert_equal 10, periods[0].start_time.hour
    assert_equal 15, periods[0].start_time.min
    assert_equal 12, periods[0].end_time.hour
  end

  test "subtracts appointment from end of period" do
    # Create appointment at 10:45 (blocks until 12:00, end of morning session)
    appointment = Appointment.create!(
      title: "Late morning appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 10, min: 45),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # First period should now be 09:00-10:45 (appointment blocks 10:45-12:00)
    # Second period unchanged: 13:00-17:00
    assert_equal 2, periods.length
    assert_equal 9, periods[0].start_time.hour
    assert_equal 10, periods[0].end_time.hour
    assert_equal 45, periods[0].end_time.min
  end

  test "subtracts appointment from middle of period splitting it" do
    # Create appointment at 10:00 (blocks 10:00-11:15, splitting the period)
    appointment = Appointment.create!(
      title: "Mid-morning appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 10, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # First period should split into: 09:00-10:00 and 11:15-12:00
    # Third period unchanged: 13:00-17:00
    assert_equal 3, periods.length

    # First split (before appointment)
    assert_equal 9, periods[0].start_time.hour
    assert_equal 10, periods[0].end_time.hour

    # Second split (after appointment)
    assert_equal 11, periods[1].start_time.hour
    assert_equal 15, periods[1].start_time.min
    assert_equal 12, periods[1].end_time.hour

    # Afternoon unchanged
    assert_equal 13, periods[2].start_time.hour
    assert_equal 17, periods[2].end_time.hour
  end

  test "completely removes period when appointment covers it entirely" do
    # Create appointments covering entire morning (each blocks 75 minutes)
    # 09:00-10:15, 10:15-11:30 (scheduled at 10:15)
    Appointment.create!(
      title: "Appointment at 09:00",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    Appointment.create!(
      title: "Appointment at 10:15",
      scheduled_at: @test_date.to_datetime.change(hour: 10, min: 15),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_bob)
    )

    Appointment.create!(
      title: "Appointment at 11:30",
      scheduled_at: @test_date.to_datetime.change(hour: 11, min: 30),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # Morning is completely booked (09:00-10:15, 10:15-11:30, 11:30-12:45 but period ends at 12:00)
    # Only afternoon period should remain
    assert_equal 1, periods.length
    assert_equal 13, periods[0].start_time.hour
    assert_equal 17, periods[0].end_time.hour
  end

  test "excludes cancelled appointments from availability calculation" do
    # Create confirmed and cancelled appointments
    Appointment.create!(
      title: "Confirmed appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    Appointment.create!(
      title: "Cancelled appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 10, min: 15),
      status: :cancelled,
      office: @office,
      provider: @provider,
      customer: users(:customer_bob)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # Cancelled appointment should not affect availability
    # Only 09:00-10:15 should be blocked (75 minutes)
    assert_equal 2, periods.length

    # Morning: 10:15-12:00 (09:00-10:15 blocked by confirmed)
    assert_equal 10, periods[0].start_time.hour
    assert_equal 15, periods[0].start_time.min
    assert_equal 12, periods[0].end_time.hour

    # Afternoon: unchanged
    assert_equal 13, periods[1].start_time.hour
    assert_equal 17, periods[1].end_time.hour
  end

  test "available? returns true when time range is available" do
    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    # Morning slot should be available
    start_time = @test_date.to_datetime.change(hour: 9, min: 0)
    end_time = @test_date.to_datetime.change(hour: 10, min: 0)

    assert service.available?(start_time: start_time, end_time: end_time)
  end

  test "available? returns false when time range has appointment" do
    # Book 09:00 slot
    Appointment.create!(
      title: "Booked appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    # 09:00-10:00 should not be available
    start_time = @test_date.to_datetime.change(hour: 9, min: 0)
    end_time = @test_date.to_datetime.change(hour: 10, min: 0)

    assert_not service.available?(start_time: start_time, end_time: end_time)
  end

  test "available? returns false during lunch break" do
    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    # Lunch break (12:00-13:00) should not be available
    start_time = @test_date.to_datetime.change(hour: 12, min: 0)
    end_time = @test_date.to_datetime.change(hour: 13, min: 0)

    assert_not service.available?(start_time: start_time, end_time: end_time)
  end

  test "total_available_minutes calculates correctly with no appointments" do
    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    # Monday: 09:00-12:00 (3 hours) + 13:00-17:00 (4 hours) = 7 hours = 420 minutes
    assert_equal 420, service.total_available_minutes
  end

  test "total_available_minutes calculates correctly with appointments" do
    # Book 75 minutes (09:00-10:15, including buffer)
    Appointment.create!(
      title: "Morning appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    # 420 minutes - 75 minutes = 345 minutes
    assert_equal 345, service.total_available_minutes
  end

  test "handles multiple appointments in different periods" do
    # Book morning appointment
    Appointment.create!(
      title: "Morning appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 9, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_alice)
    )

    # Book afternoon appointment
    Appointment.create!(
      title: "Afternoon appointment",
      scheduled_at: @test_date.to_datetime.change(hour: 14, min: 0),
      status: :confirmed,
      office: @office,
      provider: @provider,
      customer: users(:customer_bob)
    )

    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: @test_date
    )

    periods = service.available_periods

    # Should have 3 periods: 10:00-12:00, 13:00-14:00, 15:00-17:00
    assert_equal 3, periods.length
  end
end

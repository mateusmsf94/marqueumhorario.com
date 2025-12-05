require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  # Presence validations
  test "should not save appointment without title" do
    appointment = Appointment.new(scheduled_at: 1.day.from_now, office: offices(:main_office))
    assert_not appointment.save, "Saved appointment without a title"
    assert_includes appointment.errors[:title], "can't be blank"
  end

  test "should not save appointment without scheduled_at" do
    appointment = Appointment.new(title: "Doctor Visit", office: offices(:main_office))
    assert_not appointment.save, "Saved appointment without scheduled_at"
    assert_includes appointment.errors[:scheduled_at], "can't be blank"
  end

  test "should save valid appointment" do
    appointment = appointments(:pending_appointment)
    assert appointment.persisted?, "Fixture appointment should be valid"
    assert_equal "Doctor Visit", appointment.title
    assert_equal "Annual checkup", appointment.description
  end

  # Length validations
  test "should not save appointment with title longer than 255 characters" do
    appointment = Appointment.new(
      title: "a" * 256,
      scheduled_at: 1.day.from_now,
      office: offices(:main_office)
    )
    assert_not appointment.save, "Saved appointment with title too long"
    assert_includes appointment.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should save appointment with title at maximum length" do
    appointment = Appointment.create!(
      title: "a" * 255,
      scheduled_at: 1.day.from_now,
      status: :pending,
      office: offices(:main_office)
    )
    assert appointment.persisted?, "Failed to save appointment with title at max length"
    assert_equal 255, appointment.title.length
  end

  # Status enum
  test "should have default status of pending" do
    appointment = appointments(:pending_appointment)
    assert_equal "pending", appointment.status
  end

  test "should allow valid status values" do
    appointment = appointments(:pending_appointment)

    appointment.confirmed!
    assert_equal "confirmed", appointment.status

    appointment.cancelled!
    assert_equal "cancelled", appointment.status

    appointment.completed!
    assert_equal "completed", appointment.status
  end

  test "should not allow invalid status values" do
    appointment = appointments(:pending_appointment)

    assert_raises(ActiveRecord::RecordInvalid) do
      appointment.update!(status: "invalid_status")
    end
  end

  # Custom validations
  test "should not create appointment with past scheduled_at" do
    appointment = Appointment.new(
      title: "Past Appointment",
      scheduled_at: 1.day.ago,
      office: offices(:main_office)
    )
    assert_not appointment.save, "Saved appointment with past date"
    assert_includes appointment.errors[:scheduled_at], "can't be in the past"
  end

  test "should allow updating existing appointment to past date" do
    appointment = Appointment.create!(
      title: "Future Appointment",
      scheduled_at: 1.day.from_now,
      office: offices(:main_office)
    )

    # Travel to future and update
    travel 2.days do
      appointment.title = "Updated Title"
      assert appointment.save, "Failed to update existing appointment"
    end
  end

  # UUID generation
  test "should automatically generate UUID for id" do
    appointment = appointments(:pending_appointment)

    assert_not_nil appointment.id, "ID was not generated"
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/,
                 appointment.id, "ID is not a valid UUID")
  end

  test "should have unique UUIDs for different appointments" do
    appointment1 = appointments(:pending_appointment)
    appointment2 = appointments(:confirmed_appointment)

    assert_not_equal appointment1.id, appointment2.id, "UUIDs are not unique"
  end

  # Scopes
  test "upcoming scope should return future appointments" do
    future_apt = appointments(:pending_appointment)
    past_apt = appointments(:past_appointment)

    upcoming = Appointment.upcoming
    assert_includes upcoming, future_apt
    assert_not_includes upcoming, past_apt
  end

  test "past scope should return past appointments" do
    future_apt = appointments(:pending_appointment)
    past_apt = appointments(:past_appointment)

    past = Appointment.past
    assert_includes past, past_apt
    assert_not_includes past, future_apt
  end

  test "by_status scope should filter by status" do
    confirmed_apt = appointments(:confirmed_appointment)
    pending_apt = appointments(:pending_appointment)

    confirmed_appointments = Appointment.by_status(:confirmed)
    assert_includes confirmed_appointments, confirmed_apt
    assert_not_includes confirmed_appointments, pending_apt
  end

  test "today scope should return appointments scheduled for today" do
    today_apt = appointments(:today_appointment)
    # Use pending_appointment instead of tomorrow_appointment (they're equivalent)
    tomorrow_apt = appointments(:pending_appointment)

    today_appointments = Appointment.today
    assert_includes today_appointments, today_apt
    assert_not_includes today_appointments, tomorrow_apt
  end

  # Optimistic locking
  test "should have lock_version initialized to 0" do
    appointment = appointments(:pending_appointment)

    assert_equal 0, appointment.lock_version
  end

  test "should increment lock_version on update" do
    appointment = appointments(:pending_appointment)

    initial_version = appointment.lock_version
    appointment.update!(title: "Updated Title")

    assert_equal initial_version + 1, appointment.lock_version
  end

  test "should raise stale object error on concurrent update" do
    appointment = appointments(:pending_appointment)

    # Simulate two users loading the same appointment
    user1_appointment = Appointment.find(appointment.id)
    user2_appointment = Appointment.find(appointment.id)

    # User 1 updates first
    user1_appointment.update!(title: "User 1 Update")

    # User 2 tries to update - should fail
    assert_raises(ActiveRecord::StaleObjectError) do
      user2_appointment.update!(title: "User 2 Update")
    end
  end

  # Office association
  test "should belong to office" do
    appointment = appointments(:pending_appointment)
    assert_respond_to appointment, :office
    assert_instance_of Office, appointment.office
  end

  test "should not save without office" do
    appointment = Appointment.new(
      title: "Test Appointment",
      scheduled_at: 1.day.from_now,
      office_id: nil
    )
    assert_not appointment.save
    assert_includes appointment.errors[:office], "must exist"
  end

  test "for_office scope should filter by office" do
    main_office_apts = Appointment.for_office(offices(:main_office).id)

    assert main_office_apts.all? { |apt| apt.office_id == offices(:main_office).id }
    assert main_office_apts.count > 0, "Should have appointments for main office"
  end

  # Provider association tests
  test "should allow provider to be assigned to appointment" do
    provider = users(:provider_john)
    office = offices(:main_office)
    customer = users(:customer_alice)

    appointment = Appointment.create!(
      office: office,
      customer: customer,
      provider: provider,
      title: "Test Appointment",
      scheduled_at: 2.days.from_now
    )

    assert_equal provider, appointment.provider
    assert appointment.persisted?
  end

  test "should not allow provider from different office" do
    provider = users(:provider_jane)
    office = offices(:main_office)

    # Ensure provider doesn't work at main office
    office.office_memberships.where(user: provider).destroy_all

    appointment = Appointment.new(
      office: office,
      provider: provider,  # Provider not at this office
      title: "Test",
      scheduled_at: 2.days.from_now
    )

    assert_not appointment.valid?
    assert_includes appointment.errors[:provider], "must work at this office"
  end

  test "provider can have many appointments" do
    provider = users(:provider_john)
    assert_respond_to provider, :provider_appointments
  end

  test "for_provider scope should filter by provider" do
    provider = users(:provider_john)
    provider_apts = Appointment.for_provider(provider.id)

    assert provider_apts.all? { |apt| apt.provider_id == provider.id }
    assert provider_apts.count > 0, "Should have appointments for provider"
  end

  test "appointment should have both customer and provider" do
    appointment = appointments(:pending_appointment)

    assert_respond_to appointment, :customer
    assert_respond_to appointment, :provider
    assert_instance_of User, appointment.customer
    assert_instance_of User, appointment.provider
  end

  test "defaults duration_minutes when no work schedule is found" do
    provider = users(:provider_jane)
    office = offices(:main_office)
    sunday = Time.current.next_occurring(:sunday).change(hour: 10, min: 0)

    appointment = Appointment.create!(
      office: office,
      provider: provider,
      title: "No schedule fallback",
      scheduled_at: sunday,
      status: :pending
    )

    assert_equal Appointment::DEFAULT_DURATION_MINUTES, appointment.duration_minutes
  end

  # Time calculation methods
  test "start_time should return scheduled_at" do
    appointment = appointments(:pending_appointment)
    assert_equal appointment.scheduled_at, appointment.start_time
  end

  test "end_time should calculate based on duration_minutes" do
    appointment = appointments(:pending_appointment)
    appointment.duration_minutes = 60
    expected_end_time = appointment.scheduled_at + 60.minutes
    assert_equal expected_end_time, appointment.end_time
  end

  test "time_range should return TimePeriod value object" do
    appointment = appointments(:pending_appointment)
    time_range = appointment.time_range

    assert_instance_of TimePeriod, time_range
    assert_equal appointment.start_time, time_range.start_time
    assert_equal appointment.end_time, time_range.end_time
  end

  test "time_range should reflect changes in duration_minutes" do
    appointment = appointments(:pending_appointment)
    appointment.duration_minutes = 45
    time_range = appointment.time_range

    expected_duration = 45.minutes
    assert_equal expected_duration, time_range.duration
  end
end

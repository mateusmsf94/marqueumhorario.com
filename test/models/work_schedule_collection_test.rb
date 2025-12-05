require "test_helper"

class WorkScheduleCollectionTest < ActiveSupport::TestCase
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)

    @new_office = Office.create!(name: "Test Office for Schedules", time_zone: "America/New_York")
    @new_provider = User.create!(first_name: "Test", last_name: "Provider", email: "test@example.com", password: "password", password_confirmation: "password")
    @new_office.add_manager(@new_provider)
  end

  test "initializes with 7 blank schedules" do
    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider
    )

    assert_equal 7, collection.schedules.count
    assert collection.schedules.all? { |s| s.new_record? }
    assert_equal (0..6).to_a, collection.schedules.map(&:day_of_week).sort
  end

  test "builds schedules from params" do
    params = {
      schedules: {
        "1" => { # Monday
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider,
      params: params
    )

    monday = collection.schedule_for_day(1)
    assert monday.is_active
    assert_equal 60, monday.appointment_duration_minutes
    assert_equal 15, monday.buffer_minutes_between_appointments
    assert_equal [ { "start" => "09:00", "end" => "17:00" } ], monday.work_periods
  end

  test "validates only open days" do
    # Create collection with Monday open but invalid
    params = {
      schedules: {
        "1" => { # Monday - open but no work periods (invalid)
          is_open: "1",
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        },
        "2" => { # Tuesday - closed (should not be validated)
          is_open: "0"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @office,
      provider: @provider,
      params: params
    )

    refute collection.valid?
    # Tuesday should not have errors because it's closed
    assert collection.schedule_for_day(2).errors.empty?
  end

  test "saves all open schedules in transaction" do
    params = {
      schedules: {
        "1" => { # Monday
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "60",
          buffer_minutes_between_appointments: "15"
        },
        "2" => { # Tuesday
          is_open: "1",
          work_periods: {
            "0" => { start: "10:00", end: "18:00" }
          },
          appointment_duration_minutes: "45",
          buffer_minutes_between_appointments: "10"
        }
      }
    }

    collection = WorkScheduleCollection.new(
      office: @new_office,
      provider: @new_provider,
      params: params
    )

    assert_difference "WorkSchedule.count", 2 do
      assert collection.save
    end

    # Verify schedules were created
    assert @new_office.work_schedules.active.for_provider(@new_provider.id).for_day(1).exists?
    assert @new_office.work_schedules.active.for_provider(@new_provider.id).for_day(2).exists?
  end

  test "loads existing schedules" do
    # Create an existing schedule for Monday for the new office/provider
    WorkSchedule.create!(
      office: @new_office,
      provider: @new_provider,
      day_of_week: 1,
      work_periods: [ { "start" => "09:00", "end" => "17:00" } ],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    collection = WorkScheduleCollection.load_existing(
      office: @new_office,
      provider: @new_provider
    )

    monday = collection.schedule_for_day(1)
    assert monday.persisted?
    assert monday.is_active

    # Other days should be blank
    tuesday = collection.schedule_for_day(2)
    assert tuesday.new_record?
    refute tuesday.is_active
  end
end

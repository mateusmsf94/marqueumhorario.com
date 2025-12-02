require "test_helper"

class Providers::WorkSchedulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @office = offices(:main_office)
    @provider = users(:provider_john)
    
    @new_office = Office.create!(name: "Test Office for Work Schedules", time_zone: "America/New_York")
    @new_provider = User.create!(first_name: "Test", last_name: "Provider", email: "test_ws_controller@example.com", password: "password", password_confirmation: "password")
    @new_office.add_manager(@new_provider)

    sign_in @new_provider # Sign in the new provider for tests operating on @new_office
  end

  test "should require authentication" do
    sign_out @provider
    get new_providers_office_work_schedules_path(@new_office)
    assert_redirected_to new_user_session_path
  end

  test "should require user to own office" do
    unmanaged_office = offices(:inactive_office) # This office is not managed by provider_john
    get new_providers_office_work_schedules_path(unmanaged_office)
    assert_redirected_to providers_dashboard_path
    assert_equal "Office not found or you don't have access to it.", flash[:alert]
  end

  test "should get new" do
    get new_providers_office_work_schedules_path(@new_office)
    assert_response :success
    assert_select "h1", "Set up your weekly schedule"
  end

  test "should create schedules for open days" do
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
        "2" => { # Tuesday - closed
          is_open: "0"
        }
      }
    }

    assert_difference "WorkSchedule.count", 1 do
      post providers_office_work_schedules_path(@new_office), params: params
    end

    assert_redirected_to providers_office_work_schedules_path(@new_office)
    assert_match /Work schedules configured successfully/, flash[:notice]
  end

  test "should render new with errors on validation failure" do
    params = {
      schedules: {
        "1" => { # Monday - invalid (appointment_duration_minutes is 0)
          is_open: "1",
          appointment_duration_minutes: "0", # Invalid duration
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    assert_no_difference "WorkSchedule.count" do
      post providers_office_work_schedules_path(@new_office), params: params
    end

    assert_response :unprocessable_entity
    assert_select ".text-red-800", /Please fix the following errors/
  end

  test "should get edit with existing schedules" do
    # Create existing schedule
    WorkSchedule.create!(
      office: @new_office,
      provider: @new_provider,
      day_of_week: 1,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    get edit_providers_office_work_schedules_path(@new_office)
    assert_response :success
    assert_select "h1", "Edit weekly schedule"
  end

  test "should update existing schedules" do
    # Create existing schedule for Monday
    schedule = WorkSchedule.create!(
      office: @new_office,
      provider: @new_provider,
      day_of_week: 1,
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00",
      is_active: true
    )

    params = {
      schedules: {
        "1" => { # Monday - update duration
          is_open: "1",
          work_periods: {
            "0" => { start: "09:00", end: "17:00" }
          },
          appointment_duration_minutes: "45", # Changed from 60
          buffer_minutes_between_appointments: "15"
        }
      }
    }

    patch providers_office_work_schedules_path(@new_office), params: params

    assert_redirected_to providers_office_work_schedules_path(@new_office)
    schedule.reload
    assert_equal 45, schedule.appointment_duration_minutes
  end
end

require "application_system_test_case"

class ProviderWorkSchedulesTest < ApplicationSystemTestCase
  setup do
    @provider = users(:provider_john)
    sign_in @provider
  end

  test "redirects to schedule setup after creating office" do
    visit new_providers_office_path

    fill_in "Office Name", with: "New Test Office"
    select "Pacific Time (US & Canada)", from: "Time Zone"

    click_button "Create Office"

    # Should redirect to work schedule setup (check page content instead of exact path)
    assert_text "Set up your weekly schedule"
    assert_text "New Test Office"
    assert_match %r{/providers/offices/.+/work_schedules/new}, current_path
  end

  test "can toggle day open and closed" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Monday should be closed by default
    monday_checkbox = find("input[name='schedules[1][is_open]']")
    refute monday_checkbox.checked?

    # Check the checkbox to open Monday
    monday_checkbox.check

    # Work hour inputs should now be visible
    within "[data-work-periods-day-value='1']" do
      assert find("[data-work-periods-target='inputs']", visible: :all).visible?
    end

    # Uncheck to close Monday
    monday_checkbox.uncheck

    # Work hour inputs should be hidden
    within "[data-work-periods-day-value='1']" do
      refute find("[data-work-periods-target='inputs']", visible: :all).visible?
    end
  end

  test "can add and remove work periods" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Open Monday
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      # Should have 1 period by default
      assert_equal 1, all("[data-work-periods-target='period']").count

      # Click "Add another time period"
      click_button "Add another time period"

      # Should now have 2 periods
      assert_equal 2, all("[data-work-periods-target='period']").count

      # Click remove on the second period
      all("button", text: "Remove").last.click

      # Should be back to 1 period
      assert_equal 1, all("[data-work-periods-target='period']").count
    end
  end

  test "can submit valid schedule" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Set up Monday schedule
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      # Set values using JavaScript since inputs are hidden and controlled by Flatpickr
      page.execute_script(
        "document.querySelector(\"input[name='schedules[1][slot_duration_minutes]']\").value = '01:00'"
      )
      page.execute_script(
        "document.querySelector(\"input[name='schedules[1][slot_buffer_minutes]']\").value = '00:15'"
      )
    end

    click_button "Save Schedule"

    # Should redirect to week grid preview with success message
    assert_current_path providers_office_work_schedules_path(office)
    assert_text "Work schedules configured successfully"
    assert_text "Your Weekly Availability"

    # Verify schedule was created
    assert WorkSchedule.exists?(
      office: office,
      provider: @provider,
      day_of_week: 1,
      is_active: true
    )
  end

  test "shows validation errors" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    # Open Monday
    find("input[name='schedules[1][is_open]']").check

    within "[data-work-periods-day-value='1']" do
      # Set invalid duration (00:00 = 0 minutes)
      # This tests server-side validation
      page.execute_script(
        "document.querySelector(\"input[name='schedules[1][slot_duration_minutes]']\").value = '00:00'"
      )
    end

    click_button "Save Schedule"

    # Should show error message
    assert_text "Please fix the following errors"
    assert_text "Monday"
  end

  test "can skip schedule setup" do
    office = offices(:main_office)
    visit new_providers_office_work_schedules_path(office)

    click_link "Set up later"

    # Should go to dashboard
    assert_current_path providers_dashboard_path
  end
end

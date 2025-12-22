require "application_system_test_case"

class AppointmentConfirmationTest < ApplicationSystemTestCase
  setup do
    @provider_john = users(:provider_john)
    @customer_alice = users(:customer_alice)
    @office = offices(:main_office)
    @pending_appointment = appointments(:pending_appointment)

    # Ensure the pending appointment is associated correctly for the tests
    @pending_appointment.update!(provider: @provider_john, customer: @customer_alice, office: @office, status: :pending, confirmed_at: nil, declined_at: nil, decline_reason: nil)
  end

  test "provider confirms pending appointment" do
    sign_in @provider_john
    visit providers_dashboard_path

    # Ensure the appointment is visible
    assert_selector "h3", text: @pending_appointment.title

    click_on "Confirm"

    assert_text "Appointment confirmed successfully."
    assert_equal "confirmed", @pending_appointment.reload.status
    assert_not_nil @pending_appointment.confirmed_at
  end

  test "provider declines appointment with reason" do
    sign_in @provider_john
    visit providers_dashboard_path

    assert_selector "h3", text: @pending_appointment.title

    click_on "Decline"

    # Fill in decline reason in the modal
    assert_selector "h3", text: "Decline Appointment: #{@pending_appointment.title}"
    fill_in "Reason for Decline", with: "Provider unavailable on that day."
    click_on "Decline Appointment"

    assert_text "Appointment declined successfully."
    assert_equal "cancelled", @pending_appointment.reload.status
    assert_not_nil @pending_appointment.declined_at
    assert_equal "Provider unavailable on that day.", @pending_appointment.decline_reason
  end

  test "customer cancels appointment" do
    sign_in @customer_alice
    visit customers_appointments_path

    assert_selector "h3", text: @pending_appointment.title

    # Click the cancel button and accept the Turbo confirm dialog
    accept_confirm do
      click_on "Cancel"
    end

    assert_text "Appointment cancelled successfully."
    assert_equal "cancelled", @pending_appointment.reload.status
    assert_nil @pending_appointment.declined_at # Should be nil for customer cancellation
  end
end

require "test_helper"

class Providers::AppointmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @provider = users(:provider_john)
    @customer = users(:customer_alice)
    @office = offices(:main_office)
    @pending_appointment = appointments(:pending_appointment) # Ensure this is actually pending
    @confirmed_appointment = appointments(:confirmed_appointment)
    @completed_appointment = appointments(:completed_appointment)

    # Ensure pending_appointment is truly pending for these tests
    @pending_appointment.update!(status: :pending, confirmed_at: nil, declined_at: nil, decline_reason: nil)

    sign_in @provider
  end

  test "should confirm pending appointment" do
    assert_changes -> { @pending_appointment.reload.status }, from: "pending", to: "confirmed" do
      patch confirm_providers_appointment_url(@pending_appointment)
    end
    assert_not_nil @pending_appointment.reload.confirmed_at
    assert_redirected_to providers_dashboard_path
    assert_equal "Appointment confirmed successfully.", flash[:notice]
  end

  test "should not confirm already cancelled appointment" do
    @pending_appointment.update!(status: :cancelled)
    patch confirm_providers_appointment_url(@pending_appointment)
    assert_redirected_to providers_dashboard_path
    assert_equal "Appointment is already cancelled.", flash[:alert]
    assert_equal "cancelled", @pending_appointment.reload.status
  end

  test "should decline pending appointment with reason" do
    assert_changes -> { @pending_appointment.reload.status }, from: "pending", to: "cancelled" do
      patch decline_providers_appointment_url(@pending_appointment),
            params: { appointment: { decline_reason: "Provider unavailable" } }
    end
    assert_not_nil @pending_appointment.reload.declined_at
    assert_equal "Provider unavailable", @pending_appointment.reload.decline_reason
    assert_redirected_to providers_dashboard_path
    assert_equal "Appointment declined successfully.", flash[:notice]
  end

  test "should not decline pending appointment without reason" do
    assert_no_changes -> { @pending_appointment.reload.status } do
      patch decline_providers_appointment_url(@pending_appointment),
            params: { appointment: { decline_reason: "" } }
    end
    assert_nil @pending_appointment.reload.declined_at
    assert_nil @pending_appointment.reload.decline_reason
    assert_redirected_to providers_dashboard_path
    assert_equal "Decline reason is required.", flash[:alert]
  end

  test "should cancel pending appointment" do
    assert_changes -> { @pending_appointment.reload.status }, from: "pending", to: "cancelled" do
      patch cancel_providers_appointment_url(@pending_appointment)
    end
    assert_nil @pending_appointment.reload.declined_at
    assert_nil @pending_appointment.reload.decline_reason
    assert_redirected_to providers_dashboard_path
    assert_equal "Appointment cancelled successfully.", flash[:notice]
  end

  test "should handle ActiveRecord::StaleObjectError on concurrent confirm" do
    # Simulate two users loading the same appointment
    appointment_user1 = Appointment.find(@pending_appointment.id)
    appointment_user2 = Appointment.find(@pending_appointment.id)

    # User 1 updates first, incrementing lock_version
    appointment_user1.update!(title: "User 1 update")

    # User 2 tries to confirm with an outdated lock_version
    patch confirm_providers_appointment_url(appointment_user2), params: { lock_version: appointment_user2.lock_version }
    assert_redirected_to providers_dashboard_path
    assert_equal "This appointment was modified by another user. Please review and try again.", flash[:alert]
    assert_equal "pending", @pending_appointment.reload.status # Status should not have changed
  end

  test "should not allow unauthorized provider to confirm appointment" do
    other_provider = users(:provider_jane)
    sign_in other_provider # Sign in as a different provider

    patch confirm_providers_appointment_url(@pending_appointment)
    assert_response :not_found
    assert_equal "pending", @pending_appointment.reload.status # Status should not have changed
  end

  test "should not allow unauthorized provider to decline appointment" do
    other_provider = users(:provider_jane)
    sign_in other_provider

    patch decline_providers_appointment_url(@pending_appointment),
          params: { appointment: { decline_reason: "Not my appointment" } }
    assert_response :not_found
    assert_equal "pending", @pending_appointment.reload.status
  end

  test "should not allow unauthorized provider to cancel appointment" do
    other_provider = users(:provider_jane)
    sign_in other_provider

    patch cancel_providers_appointment_url(@pending_appointment)
    assert_response :not_found
    assert_equal "pending", @pending_appointment.reload.status
  end
end

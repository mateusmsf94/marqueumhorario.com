require "test_helper"

class Customers::AppointmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @customer = users(:customer_alice)
    @provider = users(:provider_john)
    @office = offices(:main_office)
    @customer_pending_appointment = appointments(:pending_appointment)
    @customer_completed_appointment = appointments(:completed_appointment)

    # Ensure pending appointment is actually pending for these tests
    @customer_pending_appointment.update!(status: :pending, customer: @customer, provider: @provider)
    @customer_completed_appointment.update!(status: :completed, customer: @customer, provider: @provider)

    sign_in @customer
  end

  test "should cancel pending appointment as customer" do
    assert_changes -> { @customer_pending_appointment.reload.status }, from: "pending", to: "cancelled" do
      patch cancel_customers_appointment_url(@customer_pending_appointment)
    end
    assert_nil @customer_pending_appointment.reload.declined_at # Customer cancel, no declined_at
    assert_redirected_to customers_appointments_path
    assert_equal "Appointment cancelled successfully.", flash[:notice]
  end

  test "should not cancel completed appointment as customer" do
    assert_no_changes -> { @customer_completed_appointment.reload.status } do
      patch cancel_customers_appointment_url(@customer_completed_appointment)
    end
    assert_redirected_to customers_appointments_path
    assert_equal "Completed appointments cannot be cancelled.", flash[:alert]
  end

  test "should not allow unauthorized customer to cancel another customer's appointment" do
    other_customer = users(:customer_bob)
    other_customer_appointment = appointments(:confirmed_appointment) # Assume this belongs to bob

    # Ensure the appointment actually belongs to other_customer
    other_customer_appointment.update!(customer: other_customer, provider: @provider)

    patch cancel_customers_appointment_url(other_customer_appointment)
    assert_response :not_found
    assert_equal "confirmed", other_customer_appointment.reload.status # Status should not have changed
  end
end

class Customers::AppointmentsController < ApplicationController
  # Pagination limits for appointment views
  PAST_APPOINTMENTS_LIMIT = 10

  before_action :authenticate_user!

  def index
    @upcoming_appointments = current_user.appointments.upcoming
    @past_appointments = current_user.appointments.past.limit(PAST_APPOINTMENTS_LIMIT)
    @has_provider_access = current_user.provider?
  end

  def show
    @appointment = current_user.appointments.find(params[:id])
  end

  def cancel
    @appointment = current_user.appointments.find(params[:id])

    if @appointment.completed?
      redirect_to customers_appointments_path, alert: "Completed appointments cannot be cancelled."
      return
    end

    if @appointment.cancelled!
      # TODO: Send cancellation notification
      redirect_to customers_appointments_path, notice: "Appointment cancelled successfully."
    else
      redirect_to customers_appointments_path, alert: "Failed to cancel appointment: #{@appointment.errors.full_messages.to_sentence}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to customers_appointments_path, alert: "Appointment not found or you are not authorized to cancel it."
  end
end

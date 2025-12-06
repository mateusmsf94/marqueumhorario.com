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
end

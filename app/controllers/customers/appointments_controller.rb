class Customers::AppointmentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @upcoming_appointments = current_user.appointments.upcoming
    @past_appointments = current_user.appointments.past.limit(10)
    @has_provider_access = current_user.offices.exists?
  end

  def show
    @appointment = current_user.appointments.find(params[:id])
  end
end

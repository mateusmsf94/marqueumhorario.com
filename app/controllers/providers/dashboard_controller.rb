class Providers::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_has_office

  def index
    @offices = current_user.offices.active.includes(:work_schedules)
    @work_schedules = current_user.work_schedules.active

    @pending_appointments = current_user.provider_appointments
                                     .by_status(:pending)
                                     .upcoming
                                     .includes(:customer, :office)
                                     .limit(20)

    upcoming_appointments = current_user.provider_appointments
                                      .upcoming
                                      .includes(:customer, :office)
                                      .limit(20)

    @appointments_presenter = AppointmentsPresenter.new(upcoming_appointments)
  end

  private

  def ensure_has_office
    unless current_user.offices.exists?
      redirect_to new_providers_onboarding_path,
        notice: "Welcome! Let's create your first office to get started."
    end
  end
end

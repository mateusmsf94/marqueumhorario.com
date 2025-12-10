class Providers::DashboardController < ApplicationController
  # Pagination limits for dashboard views
  DASHBOARD_APPOINTMENTS_LIMIT = 20

  before_action :authenticate_user!
  before_action :ensure_has_office

  def index
    @offices = current_user.offices.active.includes(:work_schedules)
    @work_schedules = current_user.work_schedules.active

    provider_appointments = current_user.provider_appointments

    @pending_appointments = provider_appointments
                              .by_status(:pending)
                              .upcoming
                              .includes(:customer, :office)
                              .limit(DASHBOARD_APPOINTMENTS_LIMIT)

    upcoming_appointments = provider_appointments
                              .upcoming
                              .includes(:customer, :office)
                              .limit(DASHBOARD_APPOINTMENTS_LIMIT)

    @appointments_presenter = AppointmentsPresenter.new(upcoming_appointments)
  end

  private

  def ensure_has_office
    unless current_user.provider?
      redirect_to new_providers_onboarding_path,
        notice: "Welcome! Let's create your first office to get started."
    end
  end
end

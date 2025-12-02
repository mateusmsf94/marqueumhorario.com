class Providers::OnboardingsController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_already_provider

  def new
    # Show onboarding welcome page
  end

  private

  def redirect_if_already_provider
    if current_user.offices.exists?
      redirect_to providers_dashboard_path,
        notice: "You're already a provider!"
    end
  end
end

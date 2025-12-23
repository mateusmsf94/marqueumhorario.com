# Controller for public provider booking pages
#
# Allows anonymous users to view provider profiles and availability.
# Authentication is required only for booking appointments.
class PublicProfilesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show ]

  def show
    @provider = User.find_by!(slug: params[:slug])

    # Only providers can have public booking pages
    unless @provider.provider?
      redirect_to root_path, alert: "Profile not found"
      return
    end

    @offices = @provider.offices.where(is_active: true)
    @selected_office = determine_selected_office

    if @selected_office
      @availability = calculate_weekly_availability
      @week_start = requested_week_start
    end

    @can_book = user_signed_in?
  end

  private

  def determine_selected_office
    if params[:office_id].present?
      @offices.find_by(id: params[:office_id])
    elsif @offices.count == 1
      @offices.first
    end
  end

  def calculate_weekly_availability
    calculator = WeeklyAvailabilityCalculator.new(
      office: @selected_office,
      provider: @provider,
      week_start: requested_week_start
    )
    calculator.call
  rescue WeeklyAvailabilityCalculator::CalculationError => e
    Rails.logger.error("Availability calculation failed: #{e.message}")
    nil
  end

  def requested_week_start
    if params[:week].present?
      Date.parse(params[:week]).beginning_of_week
    else
      Date.today.beginning_of_week
    end
  rescue ArgumentError, TypeError
    Date.today.beginning_of_week
  end
end

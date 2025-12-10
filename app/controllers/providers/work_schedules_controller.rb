# Controller for managing work schedules within the provider onboarding flow.
# Handles creating and editing a week's worth of schedules as a single unit.
class Providers::WorkSchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_office
  before_action :ensure_user_manages_office

  # GET /providers/offices/:office_id/work_schedules/new
  # Display form for setting up weekly schedule (initial onboarding)
  def new
    @schedule_collection = WorkScheduleCollection.new(
      office: @office,
      provider: current_user
    )
  end

  # POST /providers/offices/:office_id/work_schedules
  # Create or update all 7 day schedules from form submission
  def create
    load_schedule_collection
    save_schedule_collection(
      success_message: "Work schedules configured successfully! Here's your weekly availability:",
      failure_action: :new
    )
  end

  def show
    # Use service object to calculate weekly availability
    calculator = WeeklyAvailabilityCalculator.new(
      office: @office,
      provider: current_user,
      week_start: Date.today.beginning_of_week
    )

    result = calculator.call

    # Set instance variables for the view
    @slots_by_day = result[:slots_by_day]
    @total_slots = result[:total_slots]
    @available_slots = result[:available_slots]
    @start_date = result[:week_start]
    @end_date = result[:week_end]

  rescue WeeklyAvailabilityCalculator::CalculationError => e
    # Handle errors gracefully (e.g., no schedules set up yet)
    Rails.logger.error("Weekly availability calculation error: #{e.message}")
    @slots_by_day = {}
    @total_slots = 0
    @available_slots = 0
    @start_date = Date.today.beginning_of_week
    @end_date = Date.today.end_of_week
    flash.now[:alert] = "Unable to generate appointment slots. Please check your work schedule configuration."
  end
  # get /providers/offices/:office_id/work_schedules/edit
  # display form for editing existing weekly schedule

  def edit
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )
  end

  # PATCH /providers/offices/:office_id/work_schedules
  # Update existing schedules
  def update
    load_schedule_collection
    save_schedule_collection(
      success_message: "Work schedules updated successfully! Here's your updated weekly availability:",
      failure_action: :edit
    )
  end

  private

  # Load office from current_user's offices (auto-scopes to user's offices)
  # This ensures users can only manage their own offices
  def set_office
    @office = current_user.offices.find(params[:office_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to providers_dashboard_path,
                alert: "Office not found or you don't have access to it."
  end

  # Double-check user manages this office (belt-and-suspenders security)
  def ensure_user_manages_office
    return if @office.managed_by?(current_user)

    redirect_to providers_dashboard_path,
                alert: "You don't have permission to manage this office's schedules."
  end

  # Load existing schedule collection for the office and provider
  def load_schedule_collection
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )
  end

  # Save schedule collection with appropriate redirect or render
  def save_schedule_collection(success_message:, failure_action:)
    if @schedule_collection.update(work_schedule_params)
      redirect_to providers_office_work_schedules_path(@office),
                  notice: success_message
    else
      render failure_action, status: :unprocessable_entity
    end
  end

  # Strong parameters for work schedule form
  # Permits nested structure: schedules[day_number][is_open, work_periods, etc.]
  def work_schedule_params
    params.permit(
      schedules: [
        :is_open,
        :slot_duration_minutes,
        :slot_buffer_minutes,
        work_periods: [ :start, :end ]
      ]
    )
  end
end

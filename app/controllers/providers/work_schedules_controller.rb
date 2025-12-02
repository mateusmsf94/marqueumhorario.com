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
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )

    if @schedule_collection.update(work_schedule_params)
      redirect_to providers_office_work_schedules_path(@office),
  notice: "Work schedules configured successfully! Here's your weekly availability:"
    else
      # Re-render form with validation errors
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Load all active work schedules for this provider at this office
    @work_schedules = @office.work_schedules
                            .active
                            .for_provider(current_user.id)

    # Define date range for the grid (current week: Monday to Sunday)
    @start_date = Date.today.beginning_of_week
    @end_date = Date.today.end_of_week

    # Get appointments for the week (will be empty for new setup)
    @appointments = Appointment
                      .for_provider(current_user.id)
                      .for_office(@office.id)
                      .blocking_time
                      .where(scheduled_at: @start_date..@end_date)

    # Generate slots using SlotGenerator service
    begin
      generator = SlotGenerator.new(@work_schedules, @appointments, office_id: @office.id)
      all_slots = generator.call(@start_date, @end_date)

      # Group slots by day for easier rendering in the grid
      # Result: { Date => [AvailableSlot, AvailableSlot, ...], ... }
      @slots_by_day = all_slots.group_by { |slot| slot.start_time.to_date }

    rescue StandardError => e
      # Handle errors gracefully (e.g., no schedules set up yet)
      Rails.logger.error("SlotGenerator error: #{e.message}")
      @slots_by_day = {}
      flash.now[:alert] = "Unable to generate appointment slots. Please check your work schedule configuration."
    end

    # Calculate summary stats for display
    @total_slots = all_slots&.count || 0
    @available_slots = all_slots&.count { |slot| slot.status == "available" } || 0
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
    @schedule_collection = WorkScheduleCollection.load_existing(
      office: @office,
      provider: current_user
    )

    if @schedule_collection.update(work_schedule_params)
      redirect_to providers_office_work_schedules_path(@office),
  notice: "Work schedules updated successfully! Here's your updated weekly availability:"
    else
      render :edit, status: :unprocessable_entity
    end
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

  # Strong parameters for work schedule form
  # Permits nested structure: schedules[day_number][is_open, work_periods, etc.]
  def work_schedule_params
    params.permit(
      schedules: [
        :is_open,
        :appointment_duration_minutes,
        :buffer_minutes_between_appointments,
        work_periods: [ :start, :end ]
      ]
    )
  end
end

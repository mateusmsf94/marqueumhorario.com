# Controller for creating appointment bookings from public provider pages
#
# Requires authentication. Validates slot availability before booking.
class BookingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_provider
  before_action :set_office

  def new
    @slot_start = parse_datetime(params[:slot_start])
    @slot_end = parse_datetime(params[:slot_end])

    @appointment = Appointment.new(
      provider: @provider,
      office: @office,
      scheduled_at: @slot_start
    )
  end

  def create
    @appointment = Appointment.new(appointment_params)
    @appointment.customer = current_user
    @appointment.provider = @provider
    @appointment.office = @office
    @appointment.status = :pending

    if validate_slot_available && @appointment.save
      redirect_to customers_appointments_path,
        notice: "Appointment booked! The provider will confirm shortly."
    else
      @slot_start = @appointment.scheduled_at
      @slot_end = @slot_start + work_schedule_duration if work_schedule_duration
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_provider
    @provider = User.find_by!(slug: params[:slug])
    redirect_to root_path, alert: "Provider not found" unless @provider&.provider?
  end

  def set_office
    @office = @provider.offices.where(is_active: true).find(params[:office_id])
  end

  def validate_slot_available
    scheduled_at = appointment_params[:scheduled_at]

    # Find work schedule to get duration
    work_schedule = @office.work_schedules
      .active
      .for_provider(@provider.id)
      .for_day(scheduled_at.to_datetime.wday)
      .first

    unless work_schedule
      @appointment.errors.add(:base, "No work schedule found for this day")
      return false
    end

    # Check availability
    duration = work_schedule.slot_duration_minutes.minutes
    service = AvailabilityService.new(
      provider: @provider,
      office: @office,
      date: scheduled_at.to_date
    )

    end_time = scheduled_at.to_datetime + duration

    if service.available?(start_time: scheduled_at.to_datetime, end_time: end_time)
      true
    else
      @appointment.errors.add(:base, "This time slot is no longer available")
      false
    end
  end

  def work_schedule_duration
    return @work_schedule_duration if defined?(@work_schedule_duration)

    scheduled_at = appointment_params[:scheduled_at] || @slot_start
    return nil unless scheduled_at

    work_schedule = @office.work_schedules
      .active
      .for_provider(@provider.id)
      .for_day(scheduled_at.to_datetime.wday)
      .first

    @work_schedule_duration = work_schedule&.slot_duration_minutes&.minutes
  end

  def appointment_params
    params.require(:appointment).permit(:scheduled_at, :title, :description)
  end

  def parse_datetime(value)
    DateTime.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end

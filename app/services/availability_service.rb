# Service to calculate provider availability by subtracting appointments from work periods
#
# Architecture:
# 1. WorkSchedule defines when provider works (with gaps for lunch/breaks)
# 2. AvailabilityService subtracts booked appointments from work periods
# 3. SlotGenerator converts availability into discrete bookable slots
#
# Example usage:
#   service = AvailabilityService.new(
#     provider: provider_john,
#     office: main_office,
#     date: Date.today
#   )
#   available_periods = service.available_periods
#   # => [TimePeriod, ...]
class AvailabilityService
  attr_reader :provider, :office, :date, :work_schedule

  def initialize(provider:, office:, date:)
    @provider = provider
    @office = office
    @date = date
    @work_schedule = find_work_schedule
  end

  # Returns array of available time periods
  # @return [Array<TimePeriod>] array of TimePeriod objects
  def available_periods
    return [] unless work_schedule

    # Get work periods for this date
    work_periods = work_schedule.periods_for_date(date)
    return [] if work_periods.empty?

    # Get booked appointments for this provider/office/date
    booked_appointments = fetch_booked_appointments

    # Subtract appointments from work periods to get availability
    subtract_appointments_from_periods(work_periods, booked_appointments)
  end

  # Check if a specific time range is available
  # @param start_time [Time] start of requested period
  # @param end_time [Time] end of requested period
  # @return [Boolean] true if the entire period is available
  def available?(start_time:, end_time:)
    return false if start_time >= end_time

    available_periods.any? do |period|
      period.start_time <= start_time && period.end_time >= end_time
    end
  end

  # Calculate total available minutes for the day
  # @return [Integer] total available minutes
  def total_available_minutes
    total = 0
    available_periods.each do |period|
      next unless period.start_time && period.end_time

      # Convert to time objects and calculate difference in seconds
      start_time = period.start_time.to_time
      end_time = period.end_time.to_time
      seconds = end_time.to_f - start_time.to_f
      minutes = (seconds / 60).to_i
      total += minutes
    end
    total
  end

  private

  # Find the active work schedule for this provider/office/day
  # @return [WorkSchedule, nil]
  def find_work_schedule
    WorkSchedule
      .active
      .for_provider(provider.id)
      .for_office(office.id)
      .for_day(date.wday)
      .first
  end

  # Fetch all booked appointments for this provider/office/date
  # @return [ActiveRecord::Relation<Appointment>]
  def fetch_booked_appointments
    # Get appointments for this provider, office, and date
    # Exclude cancelled appointments as they don't block time slots
    start_of_day = date.beginning_of_day
    end_of_day = date.end_of_day

    Appointment
      .for_provider(provider.id)
      .for_office(office.id)
      .blocking_time
      .where(scheduled_at: start_of_day..end_of_day)
      .order(:scheduled_at)
  end

  # Subtract appointment times from work periods
  # @param periods [Array<TimePeriod>] work periods
  # @param appointments [ActiveRecord::Relation<Appointment>] booked appointments
  # @return [Array<TimePeriod>] available periods after subtracting appointments
  def subtract_appointments_from_periods(periods, appointments)
    # Start with all work periods as available
    available = periods.dup

    # For each appointment, subtract its time from available periods
    appointments.each do |appointment|
      available = PeriodSubtractorService.call(
        available,
        appointment.start_time,
        appointment.end_time
      )
    end

    available
  end
end

# frozen_string_literal: true

# Service object for calculating weekly availability for a provider at an office.
# Orchestrates work schedules, appointments, and slot generation to produce
# a weekly availability view with statistics.
#
# Usage:
#   calculator = WeeklyAvailabilityCalculator.new(
#     office: office,
#     provider: user,
#     week_start: Date.today.beginning_of_week
#   )
#   result = calculator.call
#   # => {
#   #   slots_by_day: { Date => [AvailableSlot, ...] },
#   #   total_slots: 120,
#   #   available_slots: 95,
#   #   appointments: [Appointment, ...],
#   #   work_schedules: [WorkSchedule, ...]
#   # }
#
class WeeklyAvailabilityCalculator
  # Custom error class for calculator-specific errors
  class CalculationError < StandardError; end

  attr_reader :office, :provider, :week_start

  # Initialize the calculator
  #
  # @param office [Office] The office where services are provided
  # @param provider [User] The provider (user with provider role)
  # @param week_start [Date] Start of the week (defaults to current week's Monday)
  def initialize(office:, provider:, week_start: Date.today.beginning_of_week)
    @office = office
    @provider = provider
    @week_start = week_start
  end

  # Calculate weekly availability
  #
  # @return [Hash] Hash with slots_by_day, total_slots, available_slots, etc.
  # @raise [CalculationError] If slot generation fails
  def call
    {
      slots_by_day: calculate_slots_by_day,
      total_slots: total_slots,
      available_slots: available_slots,
      appointments: appointments,
      work_schedules: work_schedules,
      week_start: week_start,
      week_end: week_end
    }
  rescue ArgumentError, KeyError => e
    # Catch expected errors and preserve cause
    raise CalculationError.new("Failed to calculate availability: #{e.message}", cause: e)
  rescue StandardError => e
    # Log unexpected errors before re-raising
    Rails.logger.error("Unexpected error in availability calculation: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise
  end

  # Get week date range
  #
  # @return [Range] Date range for the week
  def week_range
    week_start..week_end
  end

  private

  # End of the week
  #
  # @return [Date] Sunday of the current week
  def week_end
    @week_end ||= week_start.end_of_week
  end

  # Load all active work schedules for this provider at this office
  #
  # @return [ActiveRecord::Relation<WorkSchedule>]
  def work_schedules
    @work_schedules ||= office.work_schedules
                              .active
                              .for_provider(provider.id)
  end

  # Get appointments for the week
  #
  # @return [ActiveRecord::Relation<Appointment>]
  def appointments
    @appointments ||= Appointment
                        .for_provider(provider.id)
                        .for_office(office.id)
                        .blocking_time
                        .where(scheduled_at: week_range)
  end

  # Generate all slots for the week
  #
  # @return [Array<AvailableSlot>]
  def all_slots
    @all_slots ||= begin
      generator = SlotGenerator.new(work_schedules, appointments, office_id: office.id)
      generator.call(week_start, week_end)
    end
  end

  # Group slots by day for easier rendering
  #
  # @return [Hash{Date => Array<AvailableSlot>}]
  def calculate_slots_by_day
    @slots_by_day ||= all_slots.group_by { |slot| slot.start_time.to_date }
  end

  # Total number of slots in the week
  #
  # @return [Integer]
  def total_slots
    @total_slots ||= all_slots.count
  end

  # Number of available (unboo ked) slots
  #
  # @return [Integer]
  def available_slots
    @available_slots ||= all_slots.count { |slot| slot.status == "available" }
  end
end

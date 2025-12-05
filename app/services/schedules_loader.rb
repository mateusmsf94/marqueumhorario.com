# frozen_string_literal: true

# Service responsible for loading existing WorkSchedule records from the database.
# Loads existing schedules or creates blank inactive schedules for days without data.
#
# Extracted from WorkScheduleCollection to separate loading concerns from form object logic.
class SchedulesLoader
  attr_reader :office, :provider

  # Initialize loader with office and provider context
  #
  # @param office [Office] The office to load schedules for
  # @param provider [User] The provider whose schedules to load
  def initialize(office:, provider:)
    @office = office
    @provider = provider
  end

  # Load existing schedules from database or create blank ones for missing days
  # Returns array of 7 WorkSchedule objects (one per day of week)
  #
  # @return [Array<WorkSchedule>] Array of existing or blank schedule objects
  def load
    SchedulingDefaults.days_of_week.map do |day_name, day_number|
      load_or_build_schedule_for_day(day_number)
    end
  end

  private

  # Load existing schedule for a day or build a blank inactive one
  #
  # @param day_number [Integer] Day of week (0-6)
  # @return [WorkSchedule] Existing or new schedule object
  def load_or_build_schedule_for_day(day_number)
    existing = find_existing_schedule(day_number)
    return existing if existing

    build_blank_schedule(day_number)
  end

  # Find existing active schedule for a specific day
  #
  # @param day_number [Integer] Day of week (0-6)
  # @return [WorkSchedule, nil] Existing schedule or nil
  def find_existing_schedule(day_number)
    office.work_schedules
          .active
          .for_provider(provider.id)
          .for_day(day_number)
          .first
  end

  # Build a blank inactive schedule for a day without existing data
  #
  # @param day_number [Integer] Day of week (0-6)
  # @return [WorkSchedule] New blank schedule object
  def build_blank_schedule(day_number)
    WorkSchedule.new(
      office: office,
      provider: provider,
      day_of_week: day_number,
      is_active: false,
      **default_attributes
    )
  end

  # Default attributes for blank schedules
  #
  # @return [Hash] Default schedule attributes
  def default_attributes
    {
      work_periods: [
        {
          "start" => SchedulingDefaults::DEFAULT_WORK_START,
          "end" => SchedulingDefaults::DEFAULT_WORK_END
        }
      ],
      slot_duration_minutes: SchedulingDefaults::DEFAULT_APPOINTMENT_DURATION,
      slot_buffer_minutes: SchedulingDefaults::DEFAULT_BUFFER_TIME,
      opening_time: SchedulingDefaults::DEFAULT_WORK_START,
      closing_time: SchedulingDefaults::DEFAULT_WORK_END
    }
  end
end

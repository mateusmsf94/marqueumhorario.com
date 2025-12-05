# frozen_string_literal: true

# Service responsible for parsing form parameters into WorkSchedule attributes.
# Handles conversion of nested params structure, time format parsing, and default values.
#
# Extracted from WorkScheduleCollection to separate parsing concerns from form object logic.
class SchedulesFormDataParser
  include TimeParsing

  attr_reader :params, :office, :provider

  # Initialize parser with form params and context
  #
  # @param params [Hash] Form params with schedules data
  # @param office [Office] The office these schedules belong to
  # @param provider [User] The provider creating/updating schedules
  def initialize(params:, office:, provider:)
    @params = params
    @office = office
    @provider = provider
  end

  # Parse form params and return array of 7 WorkSchedule objects (one per day)
  #
  # @return [Array<WorkSchedule>] Array of schedule objects for each day of week
  def parse
    SchedulingDefaults.days_of_week.map do |day_name, day_number|
      build_schedule_for_day(day_number)
    end
  end

  private

  # Build a WorkSchedule object for a specific day
  #
  # @param day_number [Integer] Day of week (0-6)
  # @return [WorkSchedule] Schedule object with parsed attributes
  def build_schedule_for_day(day_number)
    day_params = params.dig(:schedules, day_number.to_s) || {}

    WorkSchedule.new(
      office: office,
      provider: provider,
      day_of_week: day_number,
      is_active: day_params[:is_open] == "1",
      **parse_day_attributes(day_params)
    )
  end

  # Parse parameters for a single day into WorkSchedule attributes
  #
  # @param day_params [Hash] Params for one day
  # @return [Hash] Attributes hash for WorkSchedule
  def parse_day_attributes(day_params)
    return default_attributes if day_params.blank?

    work_periods_array = parse_work_periods(day_params[:work_periods])

    {
      work_periods: work_periods_array,
      appointment_duration_minutes: parse_duration(day_params[:appointment_duration_minutes]),
      buffer_minutes_between_appointments: parse_buffer(day_params[:buffer_minutes_between_appointments]),
      opening_time: work_periods_array.first&.dig("start") || SchedulingDefaults::DEFAULT_WORK_START,
      closing_time: work_periods_array.last&.dig("end") || SchedulingDefaults::DEFAULT_WORK_END
    }
  end

  # Convert work_periods params from nested hash to array format
  # Input: { "0" => { start: "09:00", end: "12:00" }, "1" => { start: "13:00", end: "17:00" } }
  # Output: [{ "start" => "09:00", "end" => "12:00" }, { "start" => "13:00", "end" => "17:00" }]
  #
  # @param periods_params [Hash, nil] Work periods from form params
  # @return [Array<Hash>] Array of period hashes with stringified keys
  def parse_work_periods(periods_params)
    return default_work_periods if periods_params.blank?

    # periods_params comes as a hash with string keys "0", "1", etc.
    # Convert to array and stringify the inner hash keys for consistency
    periods_params.values.map do |period|
      {
        "start" => period[:start] || period["start"],
        "end" => period[:end] || period["end"]
      }
    end
  end

  # Parse appointment duration, applying defaults if needed
  #
  # @param value [String, Integer, nil] Duration value from params
  # @return [Integer] Duration in minutes
  def parse_duration(value)
    parse_time_to_minutes(value) || SchedulingDefaults::DEFAULT_APPOINTMENT_DURATION
  end

  # Parse buffer time, applying defaults if needed
  #
  # @param value [String, Integer, nil] Buffer value from params
  # @return [Integer] Buffer in minutes
  def parse_buffer(value)
    parse_time_to_minutes(value) || SchedulingDefaults::DEFAULT_BUFFER_TIME
  end

  # Default attributes for blank schedules
  #
  # @return [Hash] Default schedule attributes
  def default_attributes
    {
      work_periods: default_work_periods,
      appointment_duration_minutes: SchedulingDefaults::DEFAULT_APPOINTMENT_DURATION,
      buffer_minutes_between_appointments: SchedulingDefaults::DEFAULT_BUFFER_TIME,
      opening_time: SchedulingDefaults::DEFAULT_WORK_START,
      closing_time: SchedulingDefaults::DEFAULT_WORK_END
    }
  end

  # Default work periods (single period, 9-5)
  #
  # @return [Array<Hash>] Default work period array
  def default_work_periods
    [
      {
        "start" => SchedulingDefaults::DEFAULT_WORK_START,
        "end" => SchedulingDefaults::DEFAULT_WORK_END
      }
    ]
  end
end

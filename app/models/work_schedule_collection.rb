# Form object for managing a week's worth of WorkSchedule records as a single unit.
# This encapsulates the complexity of creating/updating 7 separate database records
# from a single form submission.
class WorkScheduleCollection
  include ActiveModel::Model

  attr_accessor :office, :provider, :schedules

  # Use the same day constants from WorkSchedule model
  DAYS_OF_WEEK = WorkSchedule::DAYS_OF_WEEK

  # Initialize a new collection with 7 blank schedules (one per day)
  #
  # @param office [Office] The office these schedules belong to
  # @param provider [User] The provider (user) creating the schedules
  # @param params [Hash] Optional params hash from form submission
  def initialize(office:, provider:, params: {})
    @office = office
    @provider = provider
    @schedules = build_schedules(params)
  end

  # Class method to load existing schedules for editing
  #
  # @param office [Office] The office to load schedules for
  # @param provider [User] The provider whose schedules to load
  # @return [WorkScheduleCollection] Collection with existing or blank schedules
  def self.load_existing(office:, provider:)
    collection = new(office: office, provider: provider)
    collection.instance_variable_set(:@schedules, [])
    collection.send(:load_existing_schedules)
    collection
  end

  # Save all schedules marked as "open" in a database transaction
  # If any save fails, the entire transaction is rolled back
  #
  # @return [Boolean] true if all saves succeeded, false otherwise
  def save
    # Validate all open schedules and populate errors
    unless valid?
      # Explicitly call valid? on each open schedule to populate errors
      schedules.select { |s| schedule_is_open?(s) }.each(&:valid?)
      return false
    end

    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        next unless schedule_is_open?(schedule)
        schedule.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("WorkScheduleCollection save failed: #{e.message}")
    false
  end

  # Update existing schedules
  # Similar to save but handles updating existing records
  #
  # @param params [Hash] New params from form submission
  # @return [Boolean] true if update succeeded
  def update(params)
    update_schedules_from_params(params)

    # Validate all open schedules and populate errors
    unless valid?
      # Explicitly call valid? on each open schedule to populate errors
      schedules.select { |s| schedule_is_open?(s) }.each(&:valid?)
      return false
    end

    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        if schedule_is_open?(schedule)
          schedule.save!
        elsif schedule.persisted?
          # Mark previously open days as inactive if now closed
          schedule.update!(is_active: false)
        end
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("WorkScheduleCollection update failed: #{e.message}")
    false
  end

  # Validate only schedules marked as "open"
  # Closed days don't need validation since they won't be saved
  #
  # @return [Boolean] true if all open schedules are valid
  def valid?
    open_schedules = schedules.select { |s| schedule_is_open?(s) }
    return true if open_schedules.empty?

    open_schedules.all?(&:valid?)
  end

  # Get schedule for a specific day of the week
  #
  # @param day_of_week [Integer] Day number (0-6)
  # @return [WorkSchedule, nil] The schedule for that day
  def schedule_for_day(day_of_week)
    schedules.find { |s| s.day_of_week == day_of_week }
  end

  # Get validation errors for a specific day
  #
  # @param day_of_week [Integer] Day number (0-6)
  # @return [ActiveModel::Errors, nil] Errors for that day's schedule
  def errors_for_day(day_of_week)
    schedule_for_day(day_of_week)&.errors
  end

  private

  # Build 7 WorkSchedule objects (one for each day of the week)
  # If params are provided, populate from those; otherwise create blank schedules
  #
  # @param params [Hash] Params hash with schedules data
  # @return [Array<WorkSchedule>] Array of 7 schedules
  def build_schedules(params)
    DAYS_OF_WEEK.map do |day_name, day_number|
      day_params = params.dig(:schedules, day_number.to_s) || {}

      WorkSchedule.new(
        office: office,
        provider: provider,
        day_of_week: day_number,
        is_active: day_params[:is_open] == "1",
        **parse_day_params(day_params)
      )
    end
  end

  # Parse params for a single day into WorkSchedule attributes
  #
  # @param params [Hash] Params for one day
  # @return [Hash] Attributes hash for WorkSchedule.new
  def parse_day_params(params)
    return default_schedule_params if params.blank?

    work_periods_array = parse_work_periods(params[:work_periods])

    {
      work_periods: work_periods_array,
      appointment_duration_minutes: params[:appointment_duration_minutes].present? ? params[:appointment_duration_minutes].to_i : 60,
      buffer_minutes_between_appointments: params[:buffer_minutes_between_appointments].present? ? params[:buffer_minutes_between_appointments].to_i : 15,
      # Set opening/closing times for backward compatibility
      opening_time: work_periods_array.first&.dig("start") || "09:00",
      closing_time: work_periods_array.last&.dig("end") || "17:00"
    }
  end

  # Convert work_periods params from nested hash to array format
  # Input: { "0" => { start: "09:00", end: "12:00" }, "1" => { start: "13:00", end: "17:00" } }
  # Output: [{ "start" => "09:00", "end" => "12:00" }, { "start" => "13:00", "end" => "17:00" }]
  #
  # @param periods_params [Hash, nil] Work periods from form params
  # @return [Array<Hash>] Array of period hashes
  def parse_work_periods(periods_params)
    return [{ "start" => "09:00", "end" => "17:00" }] if periods_params.blank?

    # periods_params comes as a hash with string keys "0", "1", etc.
    # We need to convert to array and stringify the inner hash keys
    periods_params.values.map do |period|
      {
        "start" => period[:start] || period["start"],
        "end" => period[:end] || period["end"]
      }
    end
  end

  # Default schedule params for blank schedules
  #
  # @return [Hash] Default attributes
  def default_schedule_params
    {
      work_periods: [{ "start" => "09:00", "end" => "17:00" }],
      appointment_duration_minutes: 60,
      buffer_minutes_between_appointments: 15,
      opening_time: "09:00",
      closing_time: "17:00"
    }
  end

  # Load existing schedules from database for editing
  # If a day doesn't have a schedule, create a blank inactive one
  #
  # @return [void]
  def load_existing_schedules
    @schedules = DAYS_OF_WEEK.map do |day_name, day_number|
      existing = office.work_schedules
                      .active
                      .for_provider(provider.id)
                      .for_day(day_number)
                      .first

      if existing
        existing
      else
        # Create blank schedule for days without existing schedule
        WorkSchedule.new(
          office: office,
          provider: provider,
          day_of_week: day_number,
          is_active: false,
          **default_schedule_params
        )
      end
    end
  end

  # Update schedules with new params (for edit flow)
  #
  # @param params [Hash] New params from form
  # @return [void]
  def update_schedules_from_params(params)
    schedules.each do |schedule|
      day_params = params.dig(:schedules, schedule.day_of_week.to_s) || {}

      schedule.assign_attributes(
        is_active: day_params[:is_open] == "1",
        **parse_day_params(day_params)
      )
    end
  end

  # Check if a schedule should be saved (is marked as open)
  # Need to handle both the is_active attribute and a potential is_open virtual attribute
  #
  # @param schedule [WorkSchedule] The schedule to check
  # @return [Boolean] true if schedule is open/active
  def schedule_is_open?(schedule)
    schedule.is_active == true
  end
end
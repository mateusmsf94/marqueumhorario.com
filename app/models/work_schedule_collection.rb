# Form object for managing a week's worth of WorkSchedule records as a single unit.
# This delegates to specialized services for parsing, loading, and persistence.
#
# Refactored to follow Single Responsibility Principle - this class now only
# coordinates between services and provides the ActiveModel interface for forms.
class WorkScheduleCollection
  include ActiveModel::Model

  attr_accessor :office, :provider, :schedules

  # Initialize a new collection with 7 schedules (one per day)
  #
  # @param office [Office] The office these schedules belong to
  # @param provider [User] The provider (user) creating the schedules
  # @param params [Hash] Optional params hash from form submission
  def initialize(office:, provider:, params: {})
    @office = office
    @provider = provider
    @original_params = params
    @schedules = if params.present?
      parse_schedules_from_params(params)
    else
      build_blank_schedules
    end
  end

  # Class method to load existing schedules for editing
  #
  # @param office [Office] The office to load schedules for
  # @param provider [User] The provider whose schedules to load
  # @return [WorkScheduleCollection] Collection with existing or blank schedules
  def self.load_existing(office:, provider:)
    collection = new(office: office, provider: provider)
    collection.instance_variable_set(:@schedules, load_schedules(office, provider))
    collection
  end

  # Save all schedules marked as "open" in a database transaction
  # If any save fails, the entire transaction is rolled back
  #
  # @return [Boolean] true if all saves succeeded, false otherwise
  def save
    return false unless valid?

    persistence_service.save
  end

  # Update existing schedules
  # Similar to save but handles updating existing records
  #
  # @param params [Hash] New params from form submission
  # @return [Boolean] true if update succeeded
  def update(params)
    update_schedules_from_params(params)
    return false unless valid?

    persistence_service.update
  end

  # Validate only schedules marked as "open"
  # Closed days don't need validation since they won't be saved
  #
  # @return [Boolean] true if all open schedules are valid
  def valid?
    open_schedules = schedules.select(&:is_active?)
    return true if open_schedules.empty?

    # Explicitly validate and populate errors for open schedules
    is_valid = open_schedules.all?(&:valid?)
    
    # Populate errors from individual schedules for display
    unless is_valid
      open_schedules.each do |schedule|
        next if schedule.errors.empty?
        
        day_name = schedule.day_name
        schedule.errors.full_messages.each do |message|
          errors.add(:base, "#{day_name}: #{message}")
        end
      end
    end
    
    is_valid
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

  # Parse schedules from form params using parser service
  #
  # @param params [Hash] Form params
  # @return [Array<WorkSchedule>] Parsed schedule objects
  def parse_schedules_from_params(params)
    parser.parse
  end

  # Build blank schedules using parser service with empty params
  # This creates new unsaved records for form display
  #
  # @return [Array<WorkSchedule>] Blank schedule objects
  def build_blank_schedules
    SchedulesFormDataParser.new(params: {}, office: office, provider: provider).parse
  end

  # Load existing schedules from database
  #
  # @param office [Office] The office
  # @param provider [User] The provider
  # @return [Array<WorkSchedule>] Loaded schedule objects
  def self.load_schedules(office, provider)
    SchedulesLoader.new(office: office, provider: provider).load
  end

  # Update schedules with new params from form
  #
  # @param params [Hash] New params from form
  # @return [void]
  def update_schedules_from_params(params)
    parser = SchedulesFormDataParser.new(params: params, office: office, provider: provider)
    updated_schedules = parser.parse

    # Update existing schedule objects with new attributes
    schedules.each_with_index do |schedule, index|
      updated_schedule = updated_schedules[index]
      schedule.assign_attributes(
        is_active: updated_schedule.is_active,
        work_periods: updated_schedule.work_periods,
        slot_duration_minutes: updated_schedule.slot_duration_minutes,
        slot_buffer_minutes: updated_schedule.slot_buffer_minutes,
        opening_time: updated_schedule.opening_time,
        closing_time: updated_schedule.closing_time
      )
    end
  end

  # Get parser service instance
  #
  # @return [SchedulesFormDataParser] Parser service
  def parser
    @parser ||= SchedulesFormDataParser.new(
      params: @original_params || {},
      office: office,
      provider: provider
    )
  end

  # Get persistence service instance
  #
  # @return [SchedulesPersistenceService] Persistence service
  def persistence_service
    @persistence_service ||= SchedulesPersistenceService.new(
      schedules: schedules,
      provider: provider,
      office: office
    )
  end
end

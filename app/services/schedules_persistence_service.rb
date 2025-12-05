# frozen_string_literal: true

# Service responsible for persisting WorkSchedule records to the database.
# Handles transaction management, save/update operations, and schedule deactivation.
#
# Extracted from WorkScheduleCollection to separate persistence concerns from form object logic.
class SchedulesPersistenceService
  attr_reader :schedules, :provider, :office

  # Initialize persistence service with schedules to save
  #
  # @param schedules [Array<WorkSchedule>] Array of schedule objects to persist
  # @param provider [User] The provider whose schedules are being saved
  # @param office [Office] The office these schedules belong to
  def initialize(schedules:, provider:, office:)
    @schedules = schedules
    @provider = provider
    @office = office
  end

  # Save new schedules (only active ones) in a database transaction
  # All operations are atomic - if any fails, all are rolled back
  #
  # @return [Boolean] true if all saves succeeded, false otherwise
  def save
    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        next unless schedule.is_active?
        schedule.save!
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("SchedulesPersistenceService save failed: #{e.message}")
    false
  end

  # Update existing schedules in a database transaction
  # - Saves active schedules
  # - Deactivates schedules that were changed from active to inactive
  # - Ignores schedules that are and were inactive
  #
  # @return [Boolean] true if update succeeded, false otherwise
  def update
    ActiveRecord::Base.transaction do
      schedules.each do |schedule|
        if schedule.is_active?
          # Save active schedules (new or updated)
          schedule.save!
        elsif schedule.persisted?
          # Deactivate previously active days that are now closed
          schedule.update!(is_active: false)
        end
        # Skip non-persisted inactive schedules (were never saved, still aren't)
      end
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("SchedulesPersistenceService update failed: #{e.message}")
    false
  end

  private

  # Deactivate all existing schedules for this provider/office combination
  # Used before creating new schedules to ensure clean slate
  #
  # @return [Integer] Number of schedules deactivated
  def deactivate_existing_schedules
    office.work_schedules
          .active
          .for_provider(provider.id)
          .update_all(is_active: false)
  end
end

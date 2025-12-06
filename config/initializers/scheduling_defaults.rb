# frozen_string_literal: true

# Default configuration values for work schedules and appointments
# These values are used when creating new schedules without explicit values
module SchedulingDefaults
  # Default appointment duration in minutes
  DEFAULT_APPOINTMENT_DURATION = 50

  # Default buffer time between appointments in minutes
  DEFAULT_BUFFER_TIME = 10

  # Default work day start time (24-hour format)
  DEFAULT_WORK_START = "09:00"

  # Default work day end time (24-hour format)
  DEFAULT_WORK_END = "17:00"

  # Form checkbox values (Rails conventions)
  FORM_CHECKED_VALUE = "1"    # Value when checkbox is checked
  FORM_UNCHECKED_VALUE = "0"  # Value when checkbox is unchecked

  # Days of week mapping (inherits from WorkSchedule for consistency)
  # This will be set after WorkSchedule model loads
  def self.days_of_week
    WorkSchedule::DAYS_OF_WEEK
  end
end

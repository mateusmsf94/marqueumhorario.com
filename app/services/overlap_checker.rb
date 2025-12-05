# app/services/overlap_checker.rb
#
# Service object for checking time overlaps between appointments and time ranges.
# This centralizes the overlap detection logic that was previously duplicated in SlotGenerator.
#
# Usage:
#   appointments = Appointment.where(scheduled_at: start_date..end_date)
#   checker = OverlapChecker.new(appointments, duration: 60.minutes)
#   checker.any_overlap?(slot_start, slot_end) # => true/false
#   checker.find_overlapping(slot_start, slot_end) # => [Appointment, ...]
#
class OverlapChecker
  # @param appointments [Array<Appointment>, ActiveRecord::Relation] appointments to check against
  # @param duration [ActiveSupport::Duration, Integer, nil] duration in minutes or as Duration object
  def initialize(appointments, duration: nil)
    @appointments = appointments
    @duration = duration
  end

  # Check if any appointment overlaps with the given time range
  # @param start_time [Time, DateTime] start of the time range
  # @param end_time [Time, DateTime] end of the time range
  # @return [Boolean] true if any appointment overlaps
  def any_overlap?(start_time, end_time)
    @appointments.any? { |apt| overlaps?(apt, start_time, end_time) }
  end

  # Find all appointments that overlap with the given time range
  # @param start_time [Time, DateTime] start of the time range
  # @param end_time [Time, DateTime] end of the time range
  # @return [Array<Appointment>] appointments that overlap
  def find_overlapping(start_time, end_time)
    @appointments.select { |apt| overlaps?(apt, start_time, end_time) }
  end

  private

  # Check if a single appointment overlaps with the given time range
  # @param appointment [Appointment] the appointment to check
  # @param start_time [Time, DateTime] start of the time range
  # @param end_time [Time, DateTime] end of the time range
  # @return [Boolean] true if the appointment overlaps
  def overlaps?(appointment, start_time, end_time)
    apt_start = appointment.scheduled_at
    apt_end = calculate_appointment_end(appointment, apt_start)

    IntervalOverlap.overlaps?(apt_start, apt_end, start_time, end_time)
  end

  # Calculate when an appointment ends
  # @param appointment [Appointment] the appointment
  # @param apt_start [Time, DateTime] when the appointment starts
  # @return [Time, DateTime] when the appointment ends
  def calculate_appointment_end(appointment, apt_start)
    duration = @duration ? normalize_duration(@duration) : default_duration(appointment)
    apt_start + duration
  end

  # Default duration if none provided
  # This can be extended in the future if appointments have their own duration field
  # @param appointment [Appointment] the appointment
  # @return [ActiveSupport::Duration] default duration
  def default_duration(appointment)
    minutes = appointment.duration_minutes || Appointment::DEFAULT_DURATION_MINUTES
    minutes.minutes
  end

  def normalize_duration(duration)
    duration.is_a?(ActiveSupport::Duration) ? duration : duration.to_i.minutes
  end
end

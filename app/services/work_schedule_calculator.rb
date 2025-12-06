# Calculates business metrics for work schedules
#
# Extracts calculation logic from WorkSchedule model to maintain
# single responsibility principle and reduce model complexity.
class WorkScheduleCalculator
  include TimeParsing

  def initialize(work_schedule)
    @work_schedule = work_schedule
  end

  # Calculate total work minutes from all work periods
  # @return [Integer] total minutes across all work periods
  def total_work_minutes
    return 0 if @work_schedule.work_periods.blank?

    @work_schedule.work_periods.sum do |period|
      start_minutes = TimeParsing.parse_time_to_minutes(period["start"])
      end_minutes = TimeParsing.parse_time_to_minutes(period["end"])

      end_minutes - start_minutes
    end
  end

  # Calculate maximum appointments that can fit in a work day
  # @return [Integer] number of appointment slots available per day
  def max_appointments_per_day
    minutes = total_work_minutes
    return 0 if minutes.zero? || @work_schedule.slot_duration_minutes.zero?

    total_slot_time = @work_schedule.slot_duration_minutes + @work_schedule.slot_buffer_minutes
    (minutes / total_slot_time).floor
  end
end

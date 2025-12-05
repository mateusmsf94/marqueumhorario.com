# app/services/slot_generator.rb

class SlotGenerator
  # Immutable value object representing an appointment slot
  AvailableSlot = Data.define(:start_time, :end_time, :status, :office_id)
  # @param work_schedules [Array<WorkSchedule>, WorkSchedule] the schedule rules to use
  # @param appointments [ActiveRecord::Relation<Appointment>] appointments to check against
  # @param office_id [String] optional office_id for filtering (defaults to work_schedule's office)
  def initialize(work_schedules, appointments, office_id: nil)
    @work_schedules = Array(work_schedules)
    @office_id = office_id || @work_schedules.first&.office_id
    @appointments = appointments.select { |apt| apt.office_id == @office_id }
  end

  # Generates slots for a given date range.
  # @param start_date [Date] the first day to generate slots for
  # @param end_date [Date] the last day to generate slots for
  # @return [Array<AvailableSlot>]
  def call(start_date, end_date)
    return [] if @work_schedules.empty?

    # Ensure we're only working with schedules for this office
    office_schedules = @work_schedules.select { |ws| ws.office_id == @office_id }

    slots = []
    (start_date.to_date..end_date.to_date).each do |date|
      work_schedule = office_schedules.find { |ws| ws.day_of_week == date.wday }
      next unless work_schedule
      next unless work_schedule.appointment_duration_minutes.present?

      slots.concat(generate_slots_for_day(date, work_schedule))
    end
    slots
  end

  private

  def generate_slots_for_day(date, work_schedule)
    slots = []
    config = work_schedule.slot_configuration_for_date(date)

    config.periods.each do |period|
      period_start = period.start_time
      period_end = period.end_time
      slot_start_time = period_start

      # Generate slots only within this work period
      while slot_start_time + config.duration <= period_end
        slot_end_time = slot_start_time + config.duration

        status = check_availability(
          slot_start_time,
          slot_end_time,
          config.buffer,
          config.duration
        )

        slots << AvailableSlot.new(
          start_time: slot_start_time,
          end_time: slot_end_time,
          status: status,
          office_id: @office_id
        )

        slot_start_time += config.total_slot_duration
      end
    end

    slots
  end

  def check_availability(start_time, end_time, buffer, duration)
    checker = OverlapChecker.new(@appointments, duration: duration)
    effective_end_time = end_time + buffer
    is_busy = checker.any_overlap?(start_time, effective_end_time)
    is_busy ? SlotStatus::BUSY : SlotStatus::AVAILABLE
  end
end

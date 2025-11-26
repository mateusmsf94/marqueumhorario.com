# app/services/slot_generator.rb

class SlotGenerator
  # Using Struct for a lightweight value object for a slot
  AvailableSlot = Struct.new(:start_time, :end_time, :status, :office_id, keyword_init: true)

  # @param work_schedules [Array<WorkSchedule>, WorkSchedule] the schedule rules to use
  # @param appointments [ActiveRecord::Relation<Appointment>] appointments to check against
  # @param office_id [String] optional office_id for filtering (defaults to work_schedule's office)
  def initialize(work_schedules, appointments, office_id: nil)
    @work_schedules = Array(work_schedules)
    @office_id = office_id || @work_schedules.first&.office_id
    @appointments = appointments.select { |apt| apt.office_id == @office_id }
    @duration = @work_schedules.first&.appointment_duration_minutes&.minutes
  end

  # Generates slots for a given date range.
  # @param start_date [Date] the first day to generate slots for
  # @param end_date [Date] the last day to generate slots for
  # @return [Array<AvailableSlot>]
  def call(start_date, end_date)
    return [] if @work_schedules.empty? || @duration.nil?

    # Ensure we're only working with schedules for this office
    office_schedules = @work_schedules.select { |ws| ws.office_id == @office_id }

    slots = []
    (start_date.to_date..end_date.to_date).each do |date|
      work_schedule = office_schedules.find { |ws| ws.day_of_week == date.wday }
      next unless work_schedule

      slots.concat(generate_slots_for_day(date, work_schedule))
    end
    slots
  end

  private

  def generate_slots_for_day(date, work_schedule)
    slots = []
    slot_start_time = date.to_datetime.change(hour: work_schedule.opening_time.hour, min: work_schedule.opening_time.min)
    day_end_time = date.to_datetime.change(hour: work_schedule.closing_time.hour, min: work_schedule.closing_time.min)
    total_slot_duration = @duration + work_schedule.buffer_minutes_between_appointments.minutes

    while slot_start_time + @duration <= day_end_time
      slot_end_time = slot_start_time + @duration

      status = check_availability(slot_start_time, slot_end_time, work_schedule.buffer_minutes_between_appointments)

      slots << AvailableSlot.new(
        start_time: slot_start_time,
        end_time: slot_end_time,
        status: status,
        office_id: @office_id
      )

      slot_start_time += total_slot_duration
    end
    slots
  end

  def check_availability(start_time, end_time, buffer_minutes)
    checker = OverlapChecker.new(@appointments, duration: @duration)
    effective_end_time = end_time + buffer_minutes.minutes
    is_busy = checker.any_overlap?(start_time, effective_end_time)
    is_busy ? "busy" : "available"
  end
end

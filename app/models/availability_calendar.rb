class AvailabilityCalendar < ApplicationRecord
  # Associations
  belongs_to :office

  # Concerns
  include TemporalScopes
  temporal_scope_field :period_start

  # Validations
  validates :office_id, presence: true

  # Scopes
  scope :for_office, ->(office_id) { where(office_id: office_id) }

  # Fetches all relevant data, regenerates available/busy periods, and saves the record.
  #
  # @param work_schedules [Array<WorkSchedule>, WorkSchedule] The schedules to use for generation.
  #        If nil, it will query for all active WorkSchedules.
  # @return [Boolean] true if the record was saved, false otherwise.
  def refresh!(work_schedules: nil)
    # 1. Fetch data scoped to this office
    schedules = work_schedules || WorkSchedule.where(office_id: self.office_id, is_active: true)
    appointments = Appointment.where(office_id: self.office_id, scheduled_at: self.period_start..self.period_end)
                              .where.not(status: :cancelled)

    # 2. Generate slots
    generator = SlotGenerator.new(schedules, appointments, office_id: self.office_id)
    all_slots = generator.call(self.period_start, self.period_end)

    # 3. Partition and serialize slots
    available_slots, busy_slots = all_slots.partition { |slot| slot.status == "available" }

    self.available_periods = available_slots.map { |slot| { start_time: slot.start_time, end_time: slot.end_time } }
    self.busy_periods = busy_slots.map { |slot| { start_time: slot.start_time, end_time: slot.end_time } }

    # 4. Save the record
    save
  end
end

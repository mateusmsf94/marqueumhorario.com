class WorkSchedule < ApplicationRecord
  # Associations
  belongs_to :office

  # Validations
  validates :office_id, presence: true
  validates :day_of_week, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 6 },
                          uniqueness: { scope: [ :office_id, :day_of_week, :is_active ], if: :is_active?,
                                       message: "can only have one active schedule per day per office" }

  validates :opening_time, presence: true
  validates :closing_time, presence: true

  validates :appointment_duration_minutes, presence: true,
                                           numericality: { only_integer: true, greater_than: 0 }

  validates :buffer_minutes_between_appointments, presence: true,
                                                   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Custom validations
  validates_with TimeRangeValidator, start: :opening_time, end: :closing_time

  validate :work_day_must_accommodate_at_least_one_slot

  # Scopes
  scope :for_office, ->(office_id) { where(office_id: office_id) }

  private

  def work_day_must_accommodate_at_least_one_slot
    return unless opening_time && closing_time && appointment_duration_minutes

    # Convert times to minutes for comparison
    opening_minutes = opening_time.hour * 60 + opening_time.min
    closing_minutes = closing_time.hour * 60 + closing_time.min
    available_minutes = closing_minutes - opening_minutes

    if available_minutes < appointment_duration_minutes
      errors.add(:appointment_duration_minutes,
                 "is too long for the available work hours (#{available_minutes} minutes available)")
    end
  end
end

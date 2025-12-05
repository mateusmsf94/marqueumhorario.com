class WorkSchedule < ApplicationRecord
  include TimeParsing

  # Associations
  belongs_to :office
  belongs_to :provider, class_name: "User"

  # Validations
  validates :office_id, presence: true
  validates :provider_id, presence: true
  validates :day_of_week, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 6 },
                          uniqueness: { scope: [ :provider_id, :office_id, :is_active ], if: :is_active?, message: "can only have one active schedule per day per provider per office" }

  validates :opening_time, presence: true
  validates :closing_time, presence: true

  validates :appointment_duration_minutes, presence: true,
                                           numericality: { only_integer: true, greater_than: 0 }

  validates :buffer_minutes_between_appointments, presence: true,
                                                   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Custom validations
  validates_with TimeRangeValidator, start: :opening_time, end: :closing_time

  validate :work_day_must_accommodate_at_least_one_slot
  validates_with ProviderOfficeValidator, if: -> { provider_id? && office_id? }
  validates_with WorkPeriodValidator, if: -> { work_periods.present? }

  # Scopes
  scope :for_office, ->(office_id) { where(office_id: office_id) }
  scope :for_provider, ->(provider_id) { where(provider_id: provider_id) }
  scope :for_day, ->(day) { where(day_of_week: day) }
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  # Day of week constants
  DAYS_OF_WEEK = {
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6
  }.freeze

  # Instance methods
  def day_name
    DAYS_OF_WEEK.key(day_of_week).to_s.capitalize
  end

  # Get work periods as Time objects for a specific date
  # @param date [Date] the date to get periods for
  # @return [Array<TimePeriod>] array of TimePeriod objects
  def periods_for_date(date)
    return [] if work_periods.blank?

    work_periods.map do |period|
      TimePeriod.new(
        start_time: time_string_to_datetime(period["start"], date),
        end_time: time_string_to_datetime(period["end"], date)
      )
    end
  end

  # Calculate total work minutes from all periods
  def total_work_minutes
    return 0 unless opening_time && closing_time
    return 0 if work_periods.blank?

    work_periods.sum do |period|
      start_minutes = parse_time_to_minutes(period["start"])
      end_minutes = parse_time_to_minutes(period["end"])

      end_minutes - start_minutes
    end
  end

  # Get first period start time (for backward compatibility)
  def effective_opening_time
    return opening_time if work_periods.blank?

    work_periods.first&.dig("start")
  end

  # Get last period end time (for backward compatibility)
  def effective_closing_time
    return closing_time if work_periods.blank?

    work_periods.last&.dig("end")
  end

  def max_appointments_per_day
    return 0 if total_work_minutes.zero? || appointment_duration_minutes.zero?

    (total_work_minutes / (appointment_duration_minutes + buffer_minutes_between_appointments)).floor
  end

  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

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

  def time_string_to_datetime(time_str, date)
    parsed = parse_time_string(time_str)
    return nil unless parsed

    date.to_datetime.change(hour: parsed[:hour], min: parsed[:minute], sec: 0)
  end
end

class WorkSchedule < ApplicationRecord
  # Associations
  belongs_to :office
  belongs_to :provider, class_name: "User"

  # Validations
  validates :office_id, presence: true
  validates :provider_id, presence: true
  validates :day_of_week, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 6 },
                          uniqueness: { scope: [ :provider_id, :office_id, :is_active ], if: :is_active?,
                                       message: "can only have one active schedule per day per provider per office" }

  validates :opening_time, presence: true
  validates :closing_time, presence: true

  validates :appointment_duration_minutes, presence: true,
                                           numericality: { only_integer: true, greater_than: 0 }

  validates :buffer_minutes_between_appointments, presence: true,
                                                   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Custom validations
  validates_with TimeRangeValidator, start: :opening_time, end: :closing_time

  validate :work_day_must_accommodate_at_least_one_slot
  validate :provider_must_work_at_office, if: -> { provider_id? && office_id? }
  validate :work_periods_must_be_valid_format, if: -> { work_periods.present? }

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
  # @return [Array<Hash>] array of {start_time: Time, end_time: Time}
  def periods_for_date(date)
    return [] if work_periods.blank?

    work_periods.map do |period|
      start_parts = period["start"].split(":")
      end_parts = period["end"].split(":")

      {
        start_time: date.to_datetime.change(
          hour: start_parts[0].to_i,
          min: start_parts[1].to_i,
          sec: 0
        ),
        end_time: date.to_datetime.change(
          hour: end_parts[0].to_i,
          min: end_parts[1].to_i,
          sec: 0
        )
      }
    end
  end

  # Calculate total work minutes from all periods
  def total_work_minutes
    return legacy_total_work_minutes if work_periods.blank?

    work_periods.sum do |period|
      start_parts = period["start"].split(":").map(&:to_i)
      end_parts = period["end"].split(":").map(&:to_i)

      start_minutes = start_parts[0] * 60 + start_parts[1]
      end_minutes = end_parts[0] * 60 + end_parts[1]

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

  # Legacy calculation for backward compatibility
  def legacy_total_work_minutes
    return 0 unless opening_time && closing_time

    closing_minutes = closing_time.hour * 60 + closing_time.min
    opening_minutes = opening_time.hour * 60 + opening_time.min
    closing_minutes - opening_minutes
  end

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

  def provider_must_work_at_office
    return if provider.nil? || office.nil?

    unless office.managed_by?(provider)
      errors.add(:provider, "must work at this office")
    end
  end

  def work_periods_must_be_valid_format
    unless work_periods.is_a?(Array)
      errors.add(:work_periods, "must be an array")
      return
    end

    work_periods.each_with_index do |period, index|
      unless period.is_a?(Hash) && period["start"].present? && period["end"].present?
        errors.add(:work_periods, "period #{index + 1} must have 'start' and 'end' times")
        next
      end

      # Validate time format (HH:MM)
      unless valid_time_format?(period["start"]) && valid_time_format?(period["end"])
        errors.add(:work_periods, "period #{index + 1} has invalid time format (use HH:MM)")
        next
      end

      # Validate end time is after start time
      if time_in_minutes(period["end"]) <= time_in_minutes(period["start"])
        errors.add(:work_periods, "period #{index + 1} end time must be after start time")
      end
    end

    # Validate periods don't overlap
    validate_no_period_overlaps
  end

  def validate_no_period_overlaps
    return if work_periods.size < 2

    work_periods.each_with_index do |period1, i|
      work_periods[(i + 1)..-1].each_with_index do |period2, j|
        if periods_overlap?(period1, period2)
          errors.add(:work_periods, "periods #{i + 1} and #{i + j + 2} overlap")
        end
      end
    end
  end

  def periods_overlap?(period1, period2)
    start1 = time_in_minutes(period1["start"])
    end1 = time_in_minutes(period1["end"])
    start2 = time_in_minutes(period2["start"])
    end2 = time_in_minutes(period2["end"])

    (start1 < end2) && (end1 > start2)
  end

  def valid_time_format?(time_str)
    time_str.match?(/\A([01]?[0-9]|2[0-3]):[0-5][0-9]\z/)
  end

  def time_in_minutes(time_str)
    parts = time_str.split(":").map(&:to_i)
    parts[0] * 60 + parts[1]
  end
end

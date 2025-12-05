class Appointment < ApplicationRecord
  DEFAULT_DURATION_MINUTES = 50

  # Associations
  belongs_to :office
  belongs_to :customer, class_name: "User", optional: true
  belongs_to :provider, class_name: "User", optional: true

  # Concerns
  include TemporalScopes
  temporal_scope_field :scheduled_at
  attribute :duration_minutes, :integer, default: DEFAULT_DURATION_MINUTES

  # Validations
  validates :office_id, presence: true
  validates :title, presence: true, length: { maximum: 255 }
  validates :scheduled_at, presence: true
  validates :status, presence: true

  # Enums
  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled",
    completed: "completed"
  }, default: :pending, validate: true

  # Custom validations
  validate :scheduled_at_cannot_be_in_the_past, on: :create
  validates_with ProviderOfficeValidator, if: -> { provider_id? && office_id? }

  before_save :set_duration_from_work_schedule

  # Additional scopes (not provided by TemporalScopes)
  scope :by_status, ->(status) { where(status: status) }
  scope :for_office, ->(office_id) { where(office_id: office_id) }
  scope :for_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :for_provider, ->(provider_id) { where(provider_id: provider_id) }
  scope :blocking_time, -> { where.not(status: [ :cancelled ]) }

  # Calculate start time (uses scheduled_at)
  def start_time
    scheduled_at
  end

  # Calculate end time based on stored duration
  # @return [Time] the end time of the appointment
  def end_time
    scheduled_at + duration_minutes.minutes
  end

  # Return time range as TimePeriod value object
  # @return [TimePeriod] the appointment's time range
  def time_range
    TimePeriod.new(start_time: start_time, end_time: end_time)
  end

  private

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "can't be in the past")
    end
  end

  def set_duration_from_work_schedule
    return unless provider && office && scheduled_at

    work_schedule = WorkSchedule
      .active
      .for_provider(provider_id)
      .for_office(office_id)
      .for_day(scheduled_at.wday)
      .first

    if work_schedule
      total_minutes = work_schedule.appointment_duration_minutes + work_schedule.buffer_minutes_between_appointments
      self.duration_minutes = total_minutes
    else
      self.duration_minutes = DEFAULT_DURATION_MINUTES
    end
  end
end

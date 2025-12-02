class Appointment < ApplicationRecord
  # Associations
  belongs_to :office
  belongs_to :customer, class_name: "User", optional: true
  belongs_to :provider, class_name: "User", optional: true

  # Concerns
  include TemporalScopes
  temporal_scope_field :scheduled_at

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
  validate :provider_must_work_at_office, if: -> { provider_id? && office_id? }

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

  # Calculate end time based on work schedule duration and buffer
  # @return [Time] the end time of the appointment (includes buffer time)
  def end_time
    return scheduled_at unless provider && office

    # Find the work schedule for this appointment
    work_schedule = WorkSchedule
      .active
      .for_provider(provider_id)
      .for_office(office_id)
      .for_day(scheduled_at.wday)
      .first

    if work_schedule
      # Appointment blocks time for duration + buffer
      total_minutes = work_schedule.appointment_duration_minutes + work_schedule.buffer_minutes_between_appointments
      scheduled_at + total_minutes.minutes
    else
      # Default to 60 minutes if no schedule found
      scheduled_at + 60.minutes
    end
  end

  private

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "can't be in the past")
    end
  end

  def provider_must_work_at_office
    return if provider.nil? || office.nil?

    unless office.managed_by?(provider)
      errors.add(:provider, "must work at this office")
    end
  end
end

class Appointment < ApplicationRecord
  # Validations
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

  # Scopes
  scope :upcoming, -> { where("scheduled_at >= ?", Time.current).order(scheduled_at: :asc) }
  scope :past, -> { where("scheduled_at < ?", Time.current).order(scheduled_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :today, -> { where(scheduled_at: Time.current.all_day) }

  private

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "can't be in the past")
    end
  end
end

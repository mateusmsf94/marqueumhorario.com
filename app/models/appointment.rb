class Appointment < ApplicationRecord
  # Associations
  belongs_to :office

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

  # Additional scopes (not provided by TemporalScopes)
  scope :by_status, ->(status) { where(status: status) }
  scope :for_office, ->(office_id) { where(office_id: office_id) }

  private

  def scheduled_at_cannot_be_in_the_past
    if scheduled_at.present? && scheduled_at < Time.current
      errors.add(:scheduled_at, "can't be in the past")
    end
  end
end

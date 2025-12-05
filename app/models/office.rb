class Office < ApplicationRecord
  # Include concerns for separation of responsibilities
  include Geocodable
  include MembershipManagement

  # Associations
  has_many :appointments, dependent: :restrict_with_error
  has_many :work_schedules, dependent: :restrict_with_error
  has_many :availability_calendars, dependent: :restrict_with_error

  # User associations (users who manage this office)
  has_many :office_memberships, dependent: :destroy
  has_many :users, through: :office_memberships

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :time_zone, presence: true
  validate :time_zone_must_be_valid

  validates :address, length: { maximum: 500 }, allow_blank: true
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :state, length: { maximum: 50 }, allow_blank: true
  validates :zip_code, length: { maximum: 20 }, allow_blank: true

  validates :latitude, numericality: {
    greater_than_or_equal_to: -90,
    less_than_or_equal_to: 90
  }, allow_nil: true
  validates :longitude, numericality: {
    greater_than_or_equal_to: -180,
    less_than_or_equal_to: 180
  }, allow_nil: true

  validate :address_completeness

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_state, ->(state) { where(state: state) }
  scope :geocoded, -> { where.not(latitude: nil, longitude: nil) }

  private

  # Validate that time zone is a valid ActiveSupport::TimeZone
  #
  # @return [void]
  def time_zone_must_be_valid
    return if time_zone.blank?

    errors.add(:time_zone, "#{time_zone} is not a valid time zone") unless ActiveSupport::TimeZone[time_zone]
  end

  # Validate address completeness - require city and state if address or zip provided
  #
  # @return [void]
  def address_completeness
    if (address.present? || zip_code.present?) && (city.blank? || state.blank?)
      errors.add(:base, "City and state are required when address or zip code is provided")
    end
  end
end

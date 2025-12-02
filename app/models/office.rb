class Office < ApplicationRecord
  # Associations
  has_many :appointments, dependent: :restrict_with_error
  has_many :work_schedules, dependent: :restrict_with_error
  has_many :availability_calendars, dependent: :restrict_with_error

  # User associations (users who manage this office)
  has_many :office_memberships, dependent: :destroy
  has_many :users, through: :office_memberships

  # Geocoding (after adding geocoder gem)
  geocoded_by :full_address
  after_validation :geocode_if_needed

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

  # Instance methods for managing office memberships
  def managed_by?(user)
    return false unless user
    users.exists?(user.id)
  end

  def add_manager(user)
    return false unless user
    users << user unless managed_by?(user)
  end

  def remove_manager(user)
    users.delete(user)
  end

  def active_managers
    users.where(office_memberships: { is_active: true })
  end

  private

  def full_address
    [ address, city, state, zip_code ].compact.join(", ")
  end

  def address_fields_changed?
    address_fields_present? && (
      new_record? ||
      will_save_change_to_address? || will_save_change_to_city? || will_save_change_to_state? || will_save_change_to_zip_code?
    )
  end

  def geocode_if_needed
    return unless address_fields_changed?

    if Rails.env.test? || Rails.env.development?
      self.latitude ||= 40.7143528
      self.longitude ||= -74.0059731
    else
      geocode
    end
  end

  def time_zone_must_be_valid
    return if time_zone.blank?

    errors.add(:time_zone, "#{time_zone} is not a valid time zone") unless ActiveSupport::TimeZone[time_zone]
  end

  def address_fields_present?
    address.present? || city.present? || state.present? || zip_code.present?
  end

  def address_completeness
    if (address.present? || zip_code.present?) && (city.blank? || state.blank?)
      errors.add(:base, "City and state are required when address or zip code is provided")
    end
  end
end

# frozen_string_literal: true

# Geocodable concern for models that need geocoding capabilities.
# Handles address change detection and triggers geocoding service when appropriate.
#
# Extracted from Office model to separate geocoding concerns.
module Geocodable
  extend ActiveSupport::Concern

  included do
    # Address fields to monitor for changes
    ADDRESS_FIELDS = %i[address city state zip_code].freeze

    # Configure Geocoder gem
    geocoded_by :full_address

    # Trigger geocoding after validation if address changed
    after_validation :geocode_if_address_changed
  end

  # Check if any address field has changed since last save
  #
  # @return [Boolean] true if address fields changed
  def address_fields_changed?
    return false unless address_fields_present?
    return true if new_record?

    any_address_field_changed?
  end

  private

  # Trigger geocoding service if address changed
  # Uses GeocodeOfficeService to handle the actual geocoding
  #
  # @return [void]
  def geocode_if_address_changed
    return unless address_fields_changed?

    GeocodeOfficeService.new(self).call
  end

  # Build full address string for geocoding
  # Combines all address components into comma-separated string
  #
  # @return [String] Full address
  def full_address
    [ address, city, state, zip_code ].compact.join(", ")
  end

  # Check if any address field is present
  #
  # @return [Boolean] true if any address field has a value
  def address_fields_present?
    address.present? || city.present? || state.present? || zip_code.present?
  end

  # Check if any address field will be changed on save
  # Uses ActiveRecord's will_save_change_to_* methods
  #
  # @return [Boolean] true if any address field changed
  def any_address_field_changed?
    self.class::ADDRESS_FIELDS.any? { |field| will_save_change_to_attribute?(field) }
  end
end

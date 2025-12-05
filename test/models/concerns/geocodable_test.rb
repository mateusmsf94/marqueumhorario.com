# frozen_string_literal: true

require "test_helper"

class GeocodableTest < ActiveSupport::TestCase
  # Create a test model that includes Geocodable
  class TestOffice < ApplicationRecord
    self.table_name = "offices"
    include Geocodable
  end

  setup do
    @office = TestOffice.new(
      name: "Test Office",
      address: "123 Main St",
      city: "Springfield",
      state: "IL",
      zip_code: "62701"
    )
  end

  # Tests for address_fields_changed?
  test "address_fields_changed? returns false when no address fields present" do
    office = TestOffice.new(name: "Empty Office")
    
    assert_not office.address_fields_changed?
  end

  test "address_fields_changed? returns true for new record with address fields" do
    assert @office.new_record?
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns false for existing record with no changes" do
    @office.save!
    @office.reload
    
    assert_not @office.address_fields_changed?
  end

  test "address_fields_changed? returns true when address changes" do
    @office.save!
    @office.address = "456 Oak Ave"
    
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns true when city changes" do
    @office.save!
    @office.city = "Chicago"
    
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns true when state changes" do
    @office.save!
    @office.state = "CA"
    
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns true when zip_code changes" do
    @office.save!
    @office.zip_code = "90210"
    
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns true when multiple address fields change" do
    @office.save!
    @office.address = "789 Elm St"
    @office.city = "Los Angeles"
    @office.state = "CA"
    
    assert @office.address_fields_changed?
  end

  test "address_fields_changed? returns false when non-address field changes" do
    @office.save!
    @office.name = "Updated Name"
    
    assert_not @office.address_fields_changed?
  end

  # Tests for address_fields_present?
  test "address_fields_present? returns true when address is present" do
    office = TestOffice.new(address: "123 Main St")
    
    assert office.send(:address_fields_present?)
  end

  test "address_fields_present? returns true when city is present" do
    office = TestOffice.new(city: "Springfield")
    
    assert office.send(:address_fields_present?)
  end

  test "address_fields_present? returns true when state is present" do
    office = TestOffice.new(state: "IL")
    
    assert office.send(:address_fields_present?)
  end

  test "address_fields_present? returns true when zip_code is present" do
    office = TestOffice.new(zip_code: "62701")
    
    assert office.send(:address_fields_present?)
  end

  test "address_fields_present? returns false when all address fields blank" do
    office = TestOffice.new(name: "Office without address")
    
    assert_not office.send(:address_fields_present?)
  end

  test "address_fields_present? returns true when multiple fields present" do
    office = TestOffice.new(address: "123 Main St", city: "Springfield")
    
    assert office.send(:address_fields_present?)
  end

  # Tests for any_address_field_changed?
  test "any_address_field_changed? returns true for new record with pending changes" do
    # New records with attribute assignments show as "will_save_change"
    assert @office.send(:any_address_field_changed?)
  end

  test "any_address_field_changed? returns true when address will change" do
    @office.save!
    @office.address = "New Address"
    
    assert @office.send(:any_address_field_changed?)
  end

  test "any_address_field_changed? returns false when no address fields change" do
    @office.save!
    @office.name = "Different Name"
    
    assert_not @office.send(:any_address_field_changed?)
  end

  test "any_address_field_changed? returns false for persisted record with no changes" do
    @office.save!
    
    assert_not @office.send(:any_address_field_changed?)
  end

  # Tests for full_address
  test "full_address combines all address components" do
    expected = "123 Main St, Springfield, IL, 62701"
    
    assert_equal expected, @office.send(:full_address)
  end

  test "full_address handles missing components" do
    office = TestOffice.new(address: "123 Main St", city: "Springfield")
    expected = "123 Main St, Springfield"
    
    assert_equal expected, office.send(:full_address)
  end

  test "full_address returns empty string when all fields nil" do
    office = TestOffice.new
    
    assert_equal "", office.send(:full_address)
  end

  # Tests for ADDRESS_FIELDS constant
  test "ADDRESS_FIELDS constant includes all address fields" do
    expected_fields = %i[address city state zip_code]
    
    assert_equal expected_fields, TestOffice::ADDRESS_FIELDS
  end

  test "ADDRESS_FIELDS constant is frozen" do
    assert TestOffice::ADDRESS_FIELDS.frozen?
  end

  # Integration test for geocode_if_address_changed callback
  test "geocode_if_address_changed triggers geocoding when address changes" do
    with_geocoding_enabled do
      @office.save!
      assert_not_nil @office.latitude
      assert_not_nil @office.longitude
      
      original_lat = @office.latitude
      @office.address = "456 Oak Ave"
      @office.save!
      
      # Coordinates should be updated (Geocoder stub returns different values)
      assert_not_equal original_lat, @office.latitude
    end
  end

  test "geocode_if_address_changed preserves coordinates when address doesn't change" do
    with_geocoding_enabled do
      @office.save!
      original_lat = @office.latitude
      original_lng = @office.longitude
      
      @office.name = "New Name"
      @office.save!
      
      # Coordinates should remain the same
      assert_equal original_lat, @office.latitude
      assert_equal original_lng, @office.longitude
    end
  end

  test "geocode_if_address_changed works for new records with address" do
    office = TestOffice.new(
      name: "New Office",
      address: "123 Main St",
      city: "Springfield",
      state: "IL",
      zip_code: "62701"
    )
    
    with_geocoding_enabled do
      office.save!
      assert_not_nil office.latitude
      assert_not_nil office.longitude
    end
  end

  private

  def with_geocoding_enabled
    previous = Rails.application.config.geocoding_enabled
    Rails.application.config.geocoding_enabled = true
    
    # Setup geocoding stubs for test addresses
    Geocoder::Lookup::Test.add_stub(
      "123 Main St, Springfield, IL, 62701",
      [{ "coordinates" => [39.7817, -89.6501] }]
    )
    Geocoder::Lookup::Test.add_stub(
      "456 Oak Ave, Springfield, IL, 62701",
      [{ "coordinates" => [39.7900, -89.6600] }]
    )
    
    yield
  ensure
    Rails.application.config.geocoding_enabled = previous
    Geocoder::Lookup::Test.reset
  end
end

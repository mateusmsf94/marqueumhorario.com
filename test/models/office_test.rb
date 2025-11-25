require "test_helper"

class OfficeTest < ActiveSupport::TestCase
  def valid_attributes
    {
      name: "Test Office",
      time_zone: "America/New_York",
      is_active: true,
      address: "123 Test St",
      city: "Test City",
      state: "NY",
      zip_code: "10001"
    }
  end

  # Presence validations
  test "should not save without name" do
    office = Office.new(valid_attributes.except(:name))
    assert_not office.save, "Saved office without a name"
    assert_includes office.errors[:name], "can't be blank"
  end

  test "should not save without time_zone" do
    office = Office.new(valid_attributes.merge(time_zone: nil))
    assert_not office.save, "Saved office without a time_zone"
    assert_includes office.errors[:time_zone], "can't be blank"
  end

  # Length validations
  test "should not save with name longer than 255 characters" do
    office = Office.new(valid_attributes.merge(name: "a" * 256))
    assert_not office.save, "Saved office with name too long"
    assert_includes office.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should save with name at maximum length" do
    office = Office.create!(valid_attributes.merge(name: "a" * 255))
    assert office.persisted?
    assert_equal 255, office.name.length
  end

  test "should not save with address longer than 500 characters" do
    office = Office.new(valid_attributes.merge(address: "a" * 501))
    assert_not office.save
    assert_includes office.errors[:address], "is too long (maximum is 500 characters)"
  end

  # Time zone validation
  test "should reject invalid time zone" do
    office = Office.new(valid_attributes.merge(time_zone: "Invalid/Timezone"))
    assert_not office.save, "Saved office with invalid time_zone"
    assert_includes office.errors[:time_zone], "Invalid/Timezone is not a valid time zone"
  end

  test "should accept valid time zones" do
    [ "America/New_York", "America/Los_Angeles", "UTC", "America/Chicago" ].each do |tz|
      office = Office.new(valid_attributes.merge(name: "Office #{tz}", time_zone: tz))
      assert office.valid?, "#{tz} should be valid time zone"
    end
  end

  # Coordinate validations
  test "should validate latitude range" do
    office = Office.new(valid_attributes.merge(latitude: 91))
    assert_not office.valid?
    assert_includes office.errors[:latitude], "must be less than or equal to 90"

    office.latitude = -91
    assert_not office.valid?
    assert_includes office.errors[:latitude], "must be greater than or equal to -90"
  end

  test "should validate longitude range" do
    office = Office.new(valid_attributes.merge(longitude: 181))
    assert_not office.valid?
    assert_includes office.errors[:longitude], "must be less than or equal to 180"

    office.longitude = -181
    assert_not office.valid?
    assert_includes office.errors[:longitude], "must be greater than or equal to -180"
  end

  test "should allow nil coordinates" do
    office = Office.new(valid_attributes.merge(latitude: nil, longitude: nil))
    assert office.valid?
  end

  test "should allow valid coordinates" do
    office = Office.new(valid_attributes.merge(latitude: 40.7128, longitude: -74.0060))
    assert office.valid?
  end

  # Address completeness validation
  test "should require city and state when address is provided" do
    office = Office.new(valid_attributes.merge(city: nil, state: nil))
    assert_not office.valid?
    assert_includes office.errors[:base], "City and state are required when address or zip code is provided"
  end

  test "should require city and state when zip_code is provided" do
    office = Office.new(valid_attributes.merge(address: nil, city: nil, state: nil))
    assert_not office.valid?
    assert_includes office.errors[:base], "City and state are required when address or zip code is provided"
  end

  test "should allow blank address fields" do
    office = Office.new(valid_attributes.merge(address: nil, city: nil, state: nil, zip_code: nil))
    assert office.valid?
  end

  # Associations
  test "should have many appointments" do
    office = offices(:main_office)
    assert_respond_to office, :appointments
  end

  test "should have many work_schedules" do
    office = offices(:main_office)
    assert_respond_to office, :work_schedules
  end

  test "should have many availability_calendars" do
    office = offices(:main_office)
    assert_respond_to office, :availability_calendars
  end

  # Scopes
  test "active scope should return only active offices" do
    active_offices = Office.active
    assert active_offices.include?(offices(:main_office))
    assert_not active_offices.include?(offices(:inactive_office))
  end

  test "inactive scope should return only inactive offices" do
    inactive_offices = Office.inactive
    assert inactive_offices.include?(offices(:inactive_office))
    assert_not inactive_offices.include?(offices(:main_office))
  end

  test "by_city scope should filter by city" do
    ny_offices = Office.by_city("New York")
    assert ny_offices.include?(offices(:main_office))
    assert_not ny_offices.include?(offices(:west_coast_office))
  end

  test "by_state scope should filter by state" do
    ny_offices = Office.by_state("NY")
    assert ny_offices.include?(offices(:main_office))
    assert_not ny_offices.include?(offices(:west_coast_office))
  end

  test "geocoded scope should return only offices with coordinates" do
    geocoded_offices = Office.geocoded
    assert geocoded_offices.include?(offices(:main_office))
    assert geocoded_offices.include?(offices(:west_coast_office))
  end

  # UUID generation
  test "should automatically generate UUID for id" do
    office = offices(:main_office)
    assert_not_nil office.id
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, office.id)
  end

  test "should generate unique UUIDs" do
    office1 = Office.create!(valid_attributes)
    office2 = Office.create!(valid_attributes.merge(name: "Another Office"))
    assert_not_equal office1.id, office2.id
  end

  # Geocoding
  test "should geocode address on save" do
    office = Office.new(valid_attributes.merge(
      address: "1600 Amphitheatre Parkway",
      city: "Mountain View",
      state: "CA",
      zip_code: "94043",
      latitude: nil,
      longitude: nil
    ))

    office.save!

    # In test mode, geocoder returns default stub coordinates
    assert_not_nil office.latitude
    assert_not_nil office.longitude
  end

  # Default values
  test "should default is_active to true" do
    office = Office.create!(valid_attributes.except(:is_active))
    assert office.is_active
  end

  test "should default time_zone to UTC" do
    office = Office.new(name: "Test")
    assert_equal "UTC", office.time_zone
  end
end

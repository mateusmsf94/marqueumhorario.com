require "test_helper"

class GeocodeOfficeServiceTest < ActiveSupport::TestCase
  class FakeOffice
    attr_reader :geocode_called

    def initialize(address_changed:)
      @address_changed = address_changed
      @geocode_called = false
    end

    def address_fields_changed?
      @address_changed
    end

    def geocode
      @geocode_called = true
    end
  end

  test "geocodes when enabled and address changed" do
    office = FakeOffice.new(address_changed: true)

    GeocodeOfficeService.new(office, geocoding_enabled: true).call

    assert office.geocode_called
  end

  test "does not geocode when disabled" do
    office = FakeOffice.new(address_changed: true)

    GeocodeOfficeService.new(office, geocoding_enabled: false).call

    assert_not office.geocode_called
  end

  test "does not geocode when address unchanged" do
    office = FakeOffice.new(address_changed: false)

    GeocodeOfficeService.new(office, geocoding_enabled: true).call

    assert_not office.geocode_called
  end
end

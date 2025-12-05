class GeocodeOfficeService
  def initialize(office, geocoding_enabled: Rails.application.config.geocoding_enabled)
    @office = office
    @geocoding_enabled = geocoding_enabled
  end

  def call
    return unless @office.address_fields_changed?
    return unless @geocoding_enabled

    @office.geocode
  end
end

Geocoder.configure(
  # Geocoding service (Google Maps for production, test for development)
  lookup: Rails.env.production? ? :google : :test,

  # Google Maps API configuration
  api_key: ENV["GOOGLE_MAPS_API_KEY"],
  use_https: true,

  # Caching (optional but recommended)
  cache: Rails.cache,
  cache_prefix: "geocoder:",

  # Rate limiting
  timeout: 5,

  # Units
  units: :km,

  # Test mode configuration
  test: {
    default_stub: [
      {
        "coordinates"  => [ 40.7143528, -74.0059731 ],
        "address"      => "New York, NY, USA",
        "state"        => "New York",
        "state_code"   => "NY",
        "country"      => "United States",
        "country_code" => "US"
      }
    ]
  }
)

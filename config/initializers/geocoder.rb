Geocoder.configure(
  # Geocoding service:
  # - production: Google Maps (requires API key)
  # - development: Nominatim/OpenStreetMap (free, no API key needed)
  # - test: stubbed responses
  lookup: if Rails.env.production?
            :google
          elsif Rails.env.test?
            :test
          else
            :nominatim
          end,

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

  # Nominatim configuration (OpenStreetMap)
  # Required to set a user agent when using Nominatim
  http_headers: {
    "User-Agent" => "MarqueUmHorario (contact@marqueumhorario.com)"
  },

  # SSL configuration - skip verification in development to avoid certificate issues
  ssl_verify_mode: Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE,

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

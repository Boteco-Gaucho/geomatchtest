require "vcr"
require "webmock/rspec"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock

  # Record new cassettes only when explicitly allowed.
  # Useful to keep CI deterministic.
  config.default_cassette_options = {
    record: :none,
    match_requests_on: %i[method uri body]
  }

  config.configure_rspec_metadata!

  config.filter_sensitive_data("<MERCADO_PAGO_ACCESS_TOKEN>") do
    ENV["MERCADO_PAGO_ACCESS_TOKEN"]
  end
end

RSpec.configure do |config|
  config.around(:each, :vcr) do |example|
    cassette =
      example.metadata[:cassette] ||
      example.metadata[:full_description]
        .to_s
        .gsub(/[^a-zA-Z0-9\/]+/, "_")
        .gsub(/_{2,}/, "_")
        .downcase

    VCR.use_cassette(cassette) { example.run }
  end
end



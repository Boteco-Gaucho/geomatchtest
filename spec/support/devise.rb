require "devise/test/integration_helpers"

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end



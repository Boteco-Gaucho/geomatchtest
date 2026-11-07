require "devise/test/integration_helpers"

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end



# O Rails 8 carrega as rotas sob demanda nos testes, e é ao carregar as rotas
# (devise_for) que o Devise registra no Warden o serializador da sessão. Sem
# carregá-las antes, o sign_in de teste do primeiro pedido grava o usuário
# inteiro na sessão e o pedido seguinte quebra com
# "wrong number of arguments (given 48, expected 2)" (Devise serialize_from_session).
RSpec.configure do |config|
  config.before(:suite) { Rails.application.reload_routes_unless_loaded }
end

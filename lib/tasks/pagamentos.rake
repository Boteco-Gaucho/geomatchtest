# Diagnóstico do checkout de planos (/plans → Mercado Pago), para rodar no Shell do deploy:
#
#   bin/rails pagamentos:diagnostico                 # só confere a configuração
#   CRIAR=1 bin/rails pagamentos:diagnostico         # também abre uma preferência de teste
#   CRIAR=1 PLANO=gold bin/rails pagamentos:diagnostico
#
# A preferência de teste não cobra nada (é só o link do checkout, que expira em 1 hora) e
# o registro de pagamento criado para ela é desfeito no fim. O token nunca é exibido.
namespace :pagamentos do
  desc "Confere a configuração do Mercado Pago e (com CRIAR=1) tenta abrir um checkout de plano"
  task diagnostico: :environment do
    ok = ->(value) { value ? "OK" : "FALTANDO" }

    token = ENV["MERCADO_PAGO_ACCESS_TOKEN"].presence
    base  = ENV["APP_BASE_URL"].presence
    fallback = Rails.application.routes.default_url_options[:host].presence

    puts "MERCADO_PAGO_ACCESS_TOKEN: #{ok.(token)}#{token ? " (#{token.start_with?('TEST-') ? 'teste' : 'produção'})" : ''}"
    puts "APP_BASE_URL:              #{base || "FALTANDO — usaria #{fallback.inspect} (host fixo de production.rb)"}"
    url = (base || fallback).to_s.delete_suffix("/")
    puts "  retorno do checkout:     #{url}/meu-perfil?payment=success"
    puts "  webhook:                 #{url}/webhooks/mercado_pago"
    puts "  ⚠ o webhook precisa apontar para ESTE deploy, senão o plano não é ativado depois do pagamento." if base.blank?

    plano = Plan.where(active: true).find_by(code: ENV.fetch("PLANO", "plus"))
    puts "Plano #{ENV.fetch('PLANO', 'plus')}: #{plano ? "#{plano.name} — #{plano.price.format}" : 'NÃO ENCONTRADO (ou inativo)'}"

    next puts("\nPara testar de verdade: CRIAR=1 bin/rails pagamentos:diagnostico") unless ENV["CRIAR"] == "1"
    next puts("\nNão dá para testar sem o token e o plano.") unless token && plano

    usuario = User.order(:id).first
    puts "\nAbrindo uma preferência de teste (usuário ##{usuario.id})…"
    ActiveRecord::Base.transaction do
      payment = MercadoPago::CheckoutProService.call(user: usuario, plan: plano)
      puts "✓ Mercado Pago aceitou: #{payment.mercado_pago_checkout_url}"
      raise ActiveRecord::Rollback
    end
  rescue MercadoPago::CheckoutProService::ConfigurationError, MercadoPago::CheckoutProService::ProviderError => e
    puts "✗ #{e.message}"
  end
end

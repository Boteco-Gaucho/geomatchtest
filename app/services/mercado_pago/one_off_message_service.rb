module MercadoPago
  class OneOffMessageService
    require 'mercadopago'

    class ConfigurationError < StandardError; end
    class ProviderError < StandardError; end

    def initialize(user, amount_cents)
      @user         = user
      @amount_cents = amount_cents
      @sdk          = ::Mercadopago::SDK.new(access_token)
    end

    def self.call(user:, amount_cents:)
      new(user, amount_cents).call
    end

    def call
      create_checkout_preference
    end

    private

    attr_reader :user, :amount_cents, :sdk

    def access_token
      ENV['MERCADO_PAGO_ACCESS_TOKEN'].presence ||
        raise(ConfigurationError, "MERCADO_PAGO_ACCESS_TOKEN não configurado")
    end

    # Cria a preferência no MP e persiste os dados retornados no Payment
    def create_checkout_preference
      result   = sdk.preference.create(build_preference_payload)
      response = normalize_response(result)

      checkout_url  = response["init_point"]&.to_s
      preference_id = response["id"]&.to_s

      raise ProviderError, "Mercado Pago não retornou init_point" if checkout_url.blank?

      payment.update!(
        mercado_pago_preference_id:       preference_id,
        mercado_pago_checkout_url:        checkout_url,
        mercado_pago_payload:             response
      )

      payment
    end

    # Registro local criado antes de chamar o MP; o UUID vira external_reference
    def payment
      @payment ||= Payment.create!(
        user:         user,
        payment_type: 'one_off_message'
        # plan: nil — já configurado como optional: true na Fase 2
      )
    end

    def unit_price
      (amount_cents / 100.0).round(2)
    end

    def build_preference_payload
      {
        items: [
          {
            id:          "one_off_msg_#{payment.id}",
            title:       "Mensagem Avulsa GeoMatch",
            description: "Envio de 1 mensagem fora do limite diário",
            quantity:    1,
            currency_id: "BRL",
            unit_price:  unit_price
          }
        ],
        payer: {
          email: user.email,
          name:  user.username
        },
        external_reference: payment.id.to_s,
        notification_url:   notification_url,
        back_urls: {
          success: "#{base_url}/meu-perfil?payment=success",
          failure: "#{base_url}/meu-perfil?payment=failure",
          pending: "#{base_url}/meu-perfil?payment=pending"
        },
        auto_return:          "approved",
        binary_mode:          true,
        statement_descriptor: "GEOMATCH",
        metadata: {
          payment_id:   payment.id,
          user_id:      user.id,
          payment_type: "one_off_message"
        },
        expires:                true,
        expiration_date_from:   Time.current.iso8601,
        expiration_date_to:     (Time.current + 1.hour).iso8601
      }
    end

    def base_url
      ENV['APP_BASE_URL'].presence ||
        Rails.application.routes.default_url_options[:host].presence ||
        raise(ConfigurationError, "APP_BASE_URL não configurado")
    end

    def notification_url
      "#{base_url.to_s.delete_suffix('/')}/webhooks/mercado_pago"
    end

    def normalize_response(result)
      return {} if result.nil?
      return result["response"] if result.is_a?(Hash) && result.key?("response")
      return result[:response]  if result.is_a?(Hash) && result.key?(:response)
      result
    end
  end
end

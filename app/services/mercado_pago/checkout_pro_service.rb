module MercadoPago
  class CheckoutProService
    require 'mercadopago'

    class ConfigurationError < StandardError; end
    class ProviderError < StandardError; end

    def initialize(user, plan)
      @user = user
      @plan = plan
      @sdk = ::Mercadopago::SDK.new(access_token)
    end

    def self.call(user:, plan:)
      new(user, plan).call
    end

    def call
      create_checkout_preference
    end

    private

    attr_accessor :user, :plan, :sdk

    def access_token
      ENV['MERCADO_PAGO_ACCESS_TOKEN'].presence ||
        raise(ConfigurationError, "MERCADO_PAGO_ACCESS_TOKEN não configurado")
    end

    def create_checkout_preference
      result = sdk.preference.create(build_preference)
      response = normalize_response(result)
      update_payment(response)
    end

    def build_preference
      MercadoPago::CheckoutPreferenceBuilder.new(
        payment: payment,
        user: user,
        plan: plan
      ).call
    end

    def payment
      @payment ||= Payment.create!(user: user, plan: plan)
    end

    def update_payment(response)
      checkout_url = response["init_point"]&.to_s
      preference_id = response["id"]&.to_s
      raise ProviderError, "Mercado Pago não retornou init_point" if checkout_url.blank?

      payment.update!(
        mercado_pago_preference_id: preference_id,
        mercado_pago_checkout_url: checkout_url,
        mercado_pago_payload: response,
        mercado_pago_payment_id: response["id"]&.to_s,
        mercado_pago_merchant_order_id: response["order"]&.dig("id")&.to_s,
      )
      payment
    end

    def normalize_response(result)
      return {} if result.nil?
      return result["response"] if result.is_a?(Hash) && result.key?("response")
      return result[:response] if result.is_a?(Hash) && result.key?(:response)
      result
    end
  end
end



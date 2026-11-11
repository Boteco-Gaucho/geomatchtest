module MercadoPago
  class CheckoutPreferenceBuilder
    def initialize(payment:, user:, plan:)
      @payment = payment
      @user = user
      @plan = plan
    end

    def call
      build_preference
    end

    private

    attr_reader :payment, :user, :plan

    def build_preference
      {
        items: [
          {
            id: plan.id.to_s,
            title: plan.name,
            description: plan.description,
            quantity: 1,
            currency_id: plan.price_currency,
            unit_price: plan.price.to_f
          }
        ],
        payer: {
          email: user.email,
          name: user.username
        },
        external_reference: payment.id,
        notification_url: webhook_url,
        back_urls: {
          success: success_checkouts_url,
          failure: failure_checkouts_url,
          pending: pending_checkouts_url
        },
        auto_return: "approved",
        binary_mode: true,
        statement_descriptor: "GEOMATCH",
        metadata: {
          payment_id: payment.id,
          user_id: user.id,
          plan_id: payment.plan_id
        },
        expires: true,
        expiration_date_from: expiration_date_from,
        expiration_date_to: expiration_date_to
      }
    end

    def base_url
      ENV['APP_BASE_URL'].presence ||
        Rails.application.routes.default_url_options[:host].presence
    end

    def webhook_url
      "#{base_url.to_s.delete_suffix("/")}/webhooks/mercado_pago"
    end

    def expiration_date_from
      Time.current.iso8601
    end

    def expiration_date_to
      (Time.current + 1.hour).iso8601
    end

    def success_checkouts_url
      "#{base_url}/meu-perfil?payment=success"
    end

    def failure_checkouts_url
      "#{base_url}/meu-perfil?payment=failure"
    end

    def pending_checkouts_url
      "#{base_url}/meu-perfil?payment=pending"
    end
  end
end

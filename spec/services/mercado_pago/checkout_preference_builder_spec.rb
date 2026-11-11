require "rails_helper"

RSpec.describe MercadoPago::CheckoutPreferenceBuilder do
  describe "#call" do
    let(:plan) do
      create(
        :plan,
        id: 123,
        code: "plus",
        name: "Plus",
        description: "Plano Plus",
        price_cents: 2990,
        price_currency: "BRL",
        duration_days: 30
      )
    end
    let(:user) { create(:user, email: "user@example.com", username: "Andre", plan: plan) }
    let(:payment) { create(:payment, user: user, plan: plan) }

    subject(:payload) { described_class.new(payment: payment, user: user, plan: plan).call }

    it "builds Mercado Pago preference payload" do
      expect(payload).to include(
        items: [
          hash_including(
            id: "123",
            title: "Plus",
            description: "Plano Plus",
            quantity: 1,
            currency_id: "BRL",
            unit_price: 29.90
          )
        ],
        payer: { email: "user@example.com", name: "Andre" },
        external_reference: payment.id,
        auto_return: "approved",
        binary_mode: true,
        statement_descriptor: "GEOMATCH",
        expires: true
      )
    end

    it "includes back_urls and notification_url under the configured base_url" do
      expect(payload[:notification_url]).to include("/webhooks/mercado_pago")
      expect(payload[:back_urls]).to include(:success, :failure, :pending)

      expect(payload[:back_urls][:success]).to include("://")
      expect(payload[:back_urls][:failure]).to include("://")
      expect(payload[:back_urls][:pending]).to include("://")
    end

    it "includes metadata linking payment/user/plan" do
      expect(payload[:metadata]).to eq(
        payment_id: payment.id,
        user_id: user.id,
        plan_id: plan.id
      )
    end

    it "sets expiration window" do
      expect(payload[:expiration_date_from]).to be_present
      expect(payload[:expiration_date_to]).to be_present
    end
  end
end



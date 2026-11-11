require "rails_helper"

RSpec.describe MercadoPago::CheckoutProService do
  describe ".call" do
    let(:plan) { create(:plan, code: "plus", price_cents: 2990, duration_days: 30) }
    let(:user) { create(:user, plan: plan) }

    it "creates a Payment and updates Mercado Pago fields from provider response", :aggregate_failures do
      fake_response = {
        "id" => "pref_123",
        "init_point" => "https://mercadopago.com/checkout/abc",
        "order" => { "id" => "ord_456" }
      }

      sdk = instance_double(::Mercadopago::SDK)
      preference = instance_double("Mercadopago::Preference")
      allow(::Mercadopago::SDK).to receive(:new).and_return(sdk)
      allow(sdk).to receive(:preference).and_return(preference)
      allow(preference).to receive(:create).and_return({ "response" => fake_response })

      allow(MercadoPago::CheckoutPreferenceBuilder).to receive(:new).and_call_original
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MERCADO_PAGO_ACCESS_TOKEN").and_return("test_token")

      payment = described_class.call(user: user, plan: plan)

      expect(payment).to be_persisted
      expect(payment.user).to eq(user)
      expect(payment.plan).to eq(plan)
      expect(payment.mercado_pago_preference_id).to eq("pref_123")
      expect(payment.mercado_pago_checkout_url).to eq("https://mercadopago.com/checkout/abc")
      expect(payment.mercado_pago_merchant_order_id).to eq("ord_456")
      expect(payment.mercado_pago_payload).to include("id" => "pref_123")
    end

    it "raises ConfigurationError when access token is missing" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MERCADO_PAGO_ACCESS_TOKEN").and_return(nil)

      expect { described_class.call(user: user, plan: plan) }
        .to raise_error(MercadoPago::CheckoutProService::ConfigurationError)
    end

    it "raises ProviderError when Mercado Pago does not return init_point" do
      sdk = instance_double(::Mercadopago::SDK)
      preference = instance_double("Mercadopago::Preference")
      allow(::Mercadopago::SDK).to receive(:new).and_return(sdk)
      allow(sdk).to receive(:preference).and_return(preference)
      allow(preference).to receive(:create).and_return({ "response" => { "id" => "pref_123" } })

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MERCADO_PAGO_ACCESS_TOKEN").and_return("test_token")

      expect { described_class.call(user: user, plan: plan) }
        .to raise_error(MercadoPago::CheckoutProService::ProviderError, /init_point/)
    end

    it "can create a preference via real API (recorded)", :vcr, cassette: "mercado_pago/create_preference" do
      skip("Set VCR_RECORD=all and MERCADO_PAGO_ACCESS_TOKEN to record this cassette") unless ENV["VCR_RECORD"] == "all"

      payment = described_class.call(user: user, plan: plan)
      expect(payment.mercado_pago_checkout_url).to be_present
      expect(payment.mercado_pago_preference_id).to be_present
    end
  end
end



require "rails_helper"

RSpec.describe MercadoPago::WebhookService do
  describe ".call" do
    let(:free_plan) { create(:plan, :free) }
    let(:paid_plan) { create(:plan, code: "plus", price_cents: 2990, duration_days: 30) }
    let(:user) { create(:user, plan: free_plan) }
    let(:payment) { create(:payment, user: user, plan: paid_plan) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("MERCADO_PAGO_ACCESS_TOKEN").and_return("test_token")
    end

    it "processes a payment webhook and approves the local payment", :aggregate_failures do
      event = create(
        :webhook_event,
        topic: "payment",
        external_id: "mp_pay_123",
        payload: { "type" => "payment", "data" => { "id" => "mp_pay_123" } }
      )

      mp_payment_response = {
        "id" => "mp_pay_123",
        "status" => "approved",
        "external_reference" => payment.id,
        "order" => { "id" => "ord_1" }
      }

      sdk = instance_double(::Mercadopago::SDK)
      payment_api = instance_double("Mercadopago::Payment")
      allow(::Mercadopago::SDK).to receive(:new).and_return(sdk)
      allow(sdk).to receive(:payment).and_return(payment_api)
      allow(payment_api).to receive(:get).with("mp_pay_123").and_return({ "response" => mp_payment_response })

      described_class.call(event: event)

      event.reload
      payment.reload
      user.reload

      expect(event.status).to eq("processed")
      expect(payment.state).to eq("approved")
      expect(payment.mercado_pago_payment_id).to eq("mp_pay_123")
      expect(payment.mercado_pago_merchant_order_id).to eq("ord_1")
      expect(payment.mercado_pago_payload).to eq(mp_payment_response)
      expect(user.plan_id).to eq(paid_plan.id)
      expect(user.premium_until).to be_present
    end

    it "marks event as failed when Mercado Pago payment id is missing" do
      event = create(:webhook_event, topic: "payment", external_id: nil, payload: { "type" => "payment" })

      described_class.call(event: event)

      event.reload
      expect(event.status).to eq("failed")
      expect(event.processing_errors).to be_present
    end
  end
end



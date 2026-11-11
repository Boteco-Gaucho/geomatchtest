require "rails_helper"

RSpec.describe "Mercado Pago Webhooks", type: :request do
  describe "POST /webhooks/mercado_pago" do
    it "creates a WebhookEvent and returns accepted" do
      payload = { type: "payment", data: { id: "123456789" } }

      allow(MercadoPago::WebhookService).to receive(:call)

      expect do
        post "/webhooks/mercado_pago",
             params: payload.to_json,
             headers: { "CONTENT_TYPE" => "application/json" }
      end.to change(WebhookEvent, :count).by(1)

      expect(response).to have_http_status(:accepted)
      event = WebhookEvent.last
      expect(event.source).to eq("mercadopago")
      expect(event.topic).to eq("payment")
      expect(event.external_id).to eq("123456789")
      expect(event.status).to eq("pending")
      expect(MercadoPago::WebhookService).to have_received(:call).with(event: event)
    end

    it "returns bad_request for invalid JSON" do
      post "/webhooks/mercado_pago",
           params: "{invalid",
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
    end
  end
end



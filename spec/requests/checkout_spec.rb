require "rails_helper"

RSpec.describe "Checkout", type: :request do
  describe "POST /checkout" do
    let(:plan) { create(:plan, code: "plus", name: "Plus", price_cents: 2990, duration_days: 30) }

    context "when not authenticated" do
      it "redirects to sign in" do
        post "/checkout", params: { plan_id: plan.id }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      let(:user) { create(:user) }
      let(:payment) { instance_double(Payment, id: SecureRandom.uuid, mercado_pago_checkout_url: "https://example.com/checkout") }
      let(:service) { instance_double(MercadoPago::CheckoutProService, call: payment) }

      before do
        sign_in user, scope: :user
        allow(MercadoPago::CheckoutProService).to receive(:new).with(user, plan).and_return(service)
      end

      it "redirects to Mercado Pago checkout url (HTML)" do
        post "/checkout", params: { plan_id: plan.id }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to("https://example.com/checkout")
      end

      it "returns checkout_url (JSON)" do
        post "/checkout", params: { plan_id: plan.id }, headers: { "ACCEPT" => "application/json" }

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["checkout_url"]).to eq("https://example.com/checkout")
        expect(json["payment_id"]).to be_present
      end
    end
  end
end



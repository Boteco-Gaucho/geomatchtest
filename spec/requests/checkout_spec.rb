require "rails_helper"

RSpec.describe "Checkout", type: :request do
  describe "POST /checkout" do
    let!(:free_plan) { create(:plan, :free) }
    let(:plan) { create(:plan, code: "plus", name: "Plus", price_cents: 2990, duration_days: 30) }

    context "when not authenticated" do
      it "redirects to sign in" do
        post "/checkout", params: { plan_id: plan.id }
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      # Cadastro completo: sem isso o app manda para o onboarding antes do checkout
      let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }
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

  # Fluxo real até o Mercado Pago (HTTP simulado): botão de /plans → POST /checkout → init_point
  describe "Assinar em /plans" do
    let!(:free_plan) { create(:plan, :free) }
    let!(:plan) { create(:plan, code: "plus", name: "Plus", price_cents: 2990, duration_days: 30, description: nil) }
    let(:user) { create(:user, onboarding_completed: true, plan: free_plan) }
    let(:preferences) { %r{api\.mercadopago\.com/checkout/preferences} }

    around do |example|
      previous = ENV.to_h.slice("MERCADO_PAGO_ACCESS_TOKEN", "APP_BASE_URL")
      ENV["MERCADO_PAGO_ACCESS_TOKEN"] = "TEST-token"
      ENV["APP_BASE_URL"] = "https://app.geomatch.test"
      example.run
    ensure
      %w[MERCADO_PAGO_ACCESS_TOKEN APP_BASE_URL].each { |k| previous.key?(k) ? ENV[k] = previous[k] : ENV.delete(k) }
    end

    before { sign_in user, scope: :user }

    def assinar!
      get "/plans"
      form = Nokogiri::HTML(response.body).at_css("form.pl-cta-form")
      expect(form["data-turbo"]).to eq("false")
      post form["action"]
    end

    it "abre o checkout do Mercado Pago, com descrição e URLs deste app" do
      stub = stub_request(:post, preferences).with { |req|
        body = JSON.parse(req.body)
        item = body["items"].first
        item["description"] == "Assinatura GeoMatch Plus" && item["unit_price"] == 29.9 &&
          body["back_urls"]["success"] == "https://app.geomatch.test/meu-perfil?payment=success" &&
          body["notification_url"] == "https://app.geomatch.test/webhooks/mercado_pago"
      }.to_return(status: 201, headers: { "Content-Type" => "application/json" },
                  body: { id: "pref-1", init_point: "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=pref-1" }.to_json)

      assinar!

      expect(stub).to have_been_requested
      expect(response).to redirect_to("https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=pref-1")
    end

    it "Mercado Pago recusou: volta para /plans com o aviso e o motivo fica no log" do
      stub_request(:post, preferences).to_return(
        status: 400, headers: { "Content-Type" => "application/json" },
        body: { message: "invalid back_urls", error: "bad_request", status: 400, cause: [ { code: "invalid_back_urls", description: "back_urls.success invalid" } ] }.to_json)
      allow(Rails.logger).to receive(:error).and_call_original

      assinar!

      expect(response).to redirect_to(plans_path)
      expect(flash[:alert]).to eq("Não deu para abrir o pagamento agora. Tente de novo em instantes.")
      expect(Rails.logger).to have_received(:error).with(/Mercado Pago recusou a preferência \(HTTP 400\): invalid back_urls — back_urls\.success invalid/)
      follow_redirect!
      expect(response.body).to include("Não deu para abrir o pagamento agora.")
    end

    it "sem o token do Mercado Pago no servidor: mesmo aviso em /plans e o motivo no log" do
      ENV.delete("MERCADO_PAGO_ACCESS_TOKEN")
      allow(Rails.logger).to receive(:error).and_call_original

      assinar!

      expect(response).to redirect_to(plans_path)
      expect(Rails.logger).to have_received(:error).with(/MERCADO_PAGO_ACCESS_TOKEN não configurado/)
    end
  end
end

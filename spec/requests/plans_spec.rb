require "rails_helper"

RSpec.describe "Plans", type: :request do
  describe "GET /plans" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get "/plans"
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated" do
      let(:user) { create(:user) }

      before do
        sign_in user, scope: :user
      end

      it "renders plans" do
        free = create(:plan, :free, name: "Free", price_cents: 0, duration_days: 36500)
        plus = create(:plan, code: "plus", name: "Plus", price_cents: 2990, duration_days: 30, active: true)

        get "/plans"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(free.name, plus.name)
      end

      it "orders plans from cheapest to most expensive" do
        free = create(:plan, :free, name: "Free", price_cents: 0)
        plus = create(:plan, code: "plus", name: "Plus", price_cents: 2990)

        get "/plans"

        expect(response.body.index(free.name)).to be < response.body.index(plus.name)
      end

      it "shows recommended tag only for the plan flagged as recommended" do
        create(:plan, :free)
        recommended = create(:plan, :recommended, code: "plus", name: "Plus", price_cents: 2990)

        get "/plans"

        expect(response.body).to include("Recomendado")
        expect(response.body).to include(recommended.name)
      end

      it "shows 'Seu Plano Atual' only for the user's current plan" do
        current_plan = create(:plan, code: "plus", name: "Plus", price_cents: 2990)
        other_paid = create(:plan, code: "premium", name: "Premium", price_cents: 4990)
        user.update!(plan: current_plan)

        get "/plans"

        expect(response.body).to include("Seu Plano Atual")
        expect(response.body).to include(other_paid.name)
        expect(response.body).to include("Assinar")
      end

      it "does not show duration for free plan in the header row" do
        free = create(:plan, :free, name: "Free", duration_days: 36500)
        create(:plan, code: "plus", name: "Plus", duration_days: 30, price_cents: 2990)

        get "/plans"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(free.name)
        expect(response.body).not_to include("/ 36500 dias")
      end
    end
  end
end



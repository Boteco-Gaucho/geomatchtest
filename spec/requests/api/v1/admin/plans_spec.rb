require "rails_helper"

RSpec.describe "Api::V1::Admin::Plans", type: :request do
  # let! forces admin (and its associated plan) to be created eagerly,
  # before any expect { }.not_to change(Plan, :count) block captures the baseline.
  let!(:admin) { create(:user, admin: true) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{JwtService.encode({ sub: admin.id })}",
      "Content-Type"  => "application/json" }
  end

  describe "POST /api/v1/admin/plans" do
    # Use "gold" — not a code created by any migration, so no uniqueness conflict.
    let(:valid_params) do
      {
        plan: {
          code:            "gold",
          name:            "Gold",
          price_cents:     4990,
          price_currency:  "BRL",
          duration_days:   30,
          duration_months: 1
        }
      }
    end

    context "with valid parameters" do
      it "returns 201 Created" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: auth_headers

        expect(response).to have_http_status(:created)
      end

      it "creates a new Plan record in the database" do
        expect {
          post "/api/v1/admin/plans",
               params:  valid_params.to_json,
               headers: auth_headers
        }.to change(Plan, :count).by(1)
      end

      it "returns the created plan attributes" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["plan"]["code"]).to eq("gold")
        expect(json["plan"]["name"]).to eq("Gold")
        expect(json["plan"]["price_cents"]).to eq(4990)
      end
    end

    context "with missing required fields" do
      # Sending only a name — code, duration_days and duration_months are absent
      # and have no model-level defaults, so multiple validations fail.
      let(:incomplete_params) do
        { plan: { name: "Gold" } }
      end

      it "returns 422 Unprocessable Content (not 500)" do
        post "/api/v1/admin/plans",
             params:  incomplete_params.to_json,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns a details array with validation errors" do
        post "/api/v1/admin/plans",
             params:  incomplete_params.to_json,
             headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["details"]).to be_an(Array).and be_present
      end

      it "does not create a Plan record" do
        expect {
          post "/api/v1/admin/plans",
               params:  incomplete_params.to_json,
               headers: auth_headers
        }.not_to change(Plan, :count)
      end
    end

    context "with a negative price_cents" do
      let(:invalid_price_params) do
        { plan: valid_params[:plan].merge(price_cents: -1) }
      end

      it "returns 422 Unprocessable Content" do
        post "/api/v1/admin/plans",
             params:  invalid_price_params.to_json,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a Plan record" do
        expect {
          post "/api/v1/admin/plans",
               params:  invalid_price_params.to_json,
               headers: auth_headers
        }.not_to change(Plan, :count)
      end
    end

    context "with a duplicate code" do
      before { create(:plan, code: "gold") }

      it "returns 422 Unprocessable Content" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create a new Plan record" do
        expect {
          post "/api/v1/admin/plans",
               params:  valid_params.to_json,
               headers: auth_headers
        }.not_to change(Plan, :count)
      end

      it "returns a details array mentioning the code field" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: auth_headers

        json = JSON.parse(response.body)
        expect(json["details"].join).to match(/code/i)
      end
    end

    context "without authentication" do
      it "returns 401 Unauthorized" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authenticated as a non-admin user" do
      let!(:regular_user) { create(:user, admin: false) }
      let(:non_admin_headers) do
        { "Authorization" => "Bearer #{JwtService.encode({ sub: regular_user.id })}",
          "Content-Type"  => "application/json" }
      end

      it "returns 403 Forbidden" do
        post "/api/v1/admin/plans",
             params:  valid_params.to_json,
             headers: non_admin_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

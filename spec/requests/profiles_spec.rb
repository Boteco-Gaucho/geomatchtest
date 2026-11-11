require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "PATCH /profile" do
    let(:user) { create(:user) }

    before { sign_in user, scope: :user }

    context "when updating gender" do
      it "persists the exact capitalized value 'Mulher'" do
        patch "/profile", params: { user: { gender: "Mulher" } }

        expect(response).to have_http_status(:found) # redirects to edit_profile_path
        expect(user.reload.gender).to eq("Mulher")
      end

      it "persists 'Homem' without case mutation" do
        patch "/profile", params: { user: { gender: "Homem" } }

        expect(user.reload.gender).to eq("Homem")
      end

      it "persists 'Não Binário' without case mutation" do
        patch "/profile", params: { user: { gender: "Não Binário" } }

        expect(user.reload.gender).to eq("Não Binário")
      end
    end
  end
end

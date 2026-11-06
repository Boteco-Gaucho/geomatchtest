require "rails_helper"

# "Que tal congelar sua conta?" — passo 2 da folha "Encerrar conta" em Meu Perfil.
RSpec.describe "Congelar conta", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user)  { create(:user, onboarding_completed: true, plan: free_plan, latitude: -14.78, longitude: -39.27,
                              last_location_updated_at: Time.current) }
  let(:other) { create(:user, onboarding_completed: true, plan: free_plan) }

  describe "POST /conta/congelar" do
    it "congela, apaga a localização, tira do mapa e encerra a sessão sem apagar nada" do
      match = Match.create!(user: other, matched_user: user)
      Favorite.create!(user: user, favorited_user: other)
      sign_in user, scope: :user

      expect(ActionCable.server).to receive(:broadcast).with("map_updates", { action: "leave", user_id: user.id })
      post "/conta/congelar"

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to include("congelada")
      user.reload
      expect(user.account_frozen?).to be(true)
      expect([ user.latitude, user.longitude, user.last_location_updated_at ]).to all(be_nil)
      expect(Match.exists?(match.id)).to be(true)
      expect(user.favorites.count).to eq(1)

      get "/meu-perfil"
      expect(response).to redirect_to(new_user_session_path) # saiu da conta
    end
  end

  describe "enquanto congelada" do
    before { user.freeze_account! }

    it "some da descoberta e do mapa" do
      expect(User.visible).not_to include(user)
      expect(User.visible).to include(other)
      expect(user.hidden_from_map?).to be(true)
    end

    it "a página de perfil fica indisponível para os outros" do
      sign_in other, scope: :user
      get "/users/#{user.id}"

      expect(response).to redirect_to(discover_3d_path)
      expect(flash[:alert]).to eq("Perfil indisponível.")
    end
  end

  describe "entrar de novo descongela" do
    before { user.freeze_account! }

    it "pelo site" do
      post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }

      expect(response).to have_http_status(:redirect)
      expect(user.reload.account_frozen?).to be(false)
      expect(User.visible).to include(user)
    end

    it "pelo app (POST /api/v1/login)" do
      post "/api/v1/login", params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(user.reload.account_frozen?).to be(false)
    end

    it "senha errada não descongela" do
      post "/users/sign_in", params: { user: { email: user.email, password: "errada" } }

      expect(user.reload.account_frozen?).to be(true)
    end
  end

  it "a folha de Encerrar conta mostra o passo do congelar, escondido, depois do ENCERRAR" do
    sign_in user, scope: :user
    get "/meu-perfil"
    sheet = Nokogiri::HTML(response.body).at_css('[data-delete-account-sheet-target="backdrop"]')

    expect(sheet.at_css('[data-delete-account-sheet-target="confirmStep"]').key?("hidden")).to be(false)
    step = sheet.at_css('[data-delete-account-sheet-target="freezeStep"]')
    expect(step.key?("hidden")).to be(true)
    expect(step.at_css(".ls-title").text).to eq("Que tal congelar sua conta?")
    expect(step.css(".fz-list li").map { |li| li.text.squish }).to eq([
      "Ninguém vê seu perfil enquanto estiver congelado",
      "Fotos, conversas e favoritos ficam guardados",
      "Volte quando quiser, do jeitinho que deixou"
    ])

    freeze_form = step.at_css("form.fz-form")
    expect(freeze_form["action"]).to eq("/conta/congelar")
    expect(freeze_form["data-turbo"]).to eq("false")
    expect(freeze_form.at_css("button[type=submit]").text.squish).to eq("Vou congelar")

    leave = step.at_css('button[data-delete-account-sheet-target="leave"]')
    expect(leave.text.squish).to eq("Vou encerrar mesmo assim")
    expect(leave["type"]).to eq("submit")
    expect(leave["form"]).to eq("ds-form")
    expect(sheet.at_css("form#ds-form")["action"]).to eq("/users")
  end
end

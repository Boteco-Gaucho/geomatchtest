require "rails_helper"

# "Que tal congelar sua conta?" — passo 2 da folha "Encerrar conta" em Meu Perfil.
RSpec.describe "Congelar conta", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user)  { create(:user, onboarding_completed: true, plan: free_plan, latitude: -14.78, longitude: -39.27,
                              last_location_updated_at: Time.current) }
  let(:other) { create(:user, onboarding_completed: true, plan: free_plan) }

  describe "POST /conta/congelar" do
    it "congela, apaga a localização, tira do mapa e mostra \"Até breve!\" sem apagar nada" do
      match = Match.create!(user: other, matched_user: user)
      Favorite.create!(user: user, favorited_user: other)
      sign_in user, scope: :user

      expect(ActionCable.server).to receive(:broadcast).with("map_updates", { action: "leave", user_id: user.id })
      post "/conta/congelar"

      expect(response).to redirect_to(account_frozen_path)
      user.reload
      expect(user.account_frozen?).to be(true)
      expect([ user.latitude, user.longitude, user.last_location_updated_at ]).to all(be_nil)
      expect(Match.exists?(match.id)).to be(true)
      expect(user.favorites.count).to eq(1)
    end
  end

  describe "tela \"Até breve!\" (GET /conta/congelada)" do
    before do
      sign_in user, scope: :user
      get "/meu-perfil" # entra antes, congela depois (como quem congela já logado)
      user.freeze_account!
    end

    it "mostra a tela do mockup, sem a navegação do app" do
      get "/conta/congelada"
      page = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(page.at_css(".af-pill").text).to eq("Conta congelada")
      expect(page.at_css(".af-title").text).to eq("Até breve!")
      expect(page.at_css(".af-text").text.squish)
        .to eq("Seu perfil está escondido e tudo ficou guardado do jeitinho que você deixou. Quando der saudade, é só entrar de novo.")
      expect(page.css(".af-list li").map { |li| li.text.squish }).to eq([ "Ninguém vê seu perfil", "Fotos e conversas guardadas" ])
      expect(page.at_css('form[action="/conta/congelada/sair"] button').text).to eq("Entendi")
      expect(page.at_css('form[action="/conta/descongelar"] button').text).to eq("Mudei de ideia, descongelar agora")
      expect(page.css("form.af-form").map { |f| f["data-turbo"] }).to all(eq("false"))
      expect(page.at_css(".sidebar, .bottom-nav, nav.mobile-nav")).to be_nil
    end

    it "logada e congelada, qualquer página leva a \"Que bom que você voltou\"; JSON segue" do
      get "/meu-perfil"
      expect(response).to redirect_to(account_frozen_return_path)
      get "/discover_3d"
      expect(response).to redirect_to(account_frozen_return_path)

      get "/stories", headers: { "Accept" => "application/json" }
      expect(response).to have_http_status(:ok)
    end

    it "\"Entendi\" sai da conta, que continua congelada" do
      post "/conta/congelada/sair"

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to include("congelada")
      expect(user.reload.account_frozen?).to be(true)
      get "/meu-perfil"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  it "sem estar congelada, /conta/congelada volta a Meu Perfil" do
    sign_in user, scope: :user
    get "/conta/congelada"

    expect(response).to redirect_to(my_profile_path)
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

  describe "POST /conta/descongelar (\"Mudei de ideia, descongelar conta\")" do
    it "descongela e mostra \"Que bom que você ficou!\" em Meu Perfil" do
      sign_in user, scope: :user
      get "/meu-perfil" # entra antes, congela depois (como quem congela já logado)
      user.freeze_account!

      post "/conta/descongelar"

      expect(response).to redirect_to(my_profile_path)
      expect(user.reload.account_frozen?).to be(false)
      follow_redirect!
      toast = Nokogiri::HTML(response.body).at_css('.tt-toast--timed[data-controller="top-toast"]')
      expect(toast["data-top-toast-duration-value"]).to eq("5000")
      expect(toast.at_css(".tt-title").text).to eq("Que bom que você ficou!")
      expect(toast.at_css(".tt-text").text)
        .to eq("Sua conta foi descongelada e você já aparece de novo para quem está por perto.")
      expect(response.body).not_to include('<span class="toast__message">true</span>')

      get "/meu-perfil"
      expect(response.body).not_to include("Que bom que você ficou!") # só uma vez
    end

    it "conta que não estava congelada: só volta a Meu Perfil, sem aviso" do
      sign_in user, scope: :user
      post "/conta/descongelar"
      follow_redirect!

      expect(response.body).not_to include("Que bom que você ficou!")
    end
  end

  describe "entrar de novo com a conta congelada" do
    before { user.update!(username: "Samuel Souza"); user.freeze_account! }

    it "pelo site: não descongela e mostra \"Que bom que você voltou, Samuel!\"" do
      post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
      follow_redirect!

      expect(response).to redirect_to(account_frozen_return_path)
      expect(user.reload.account_frozen?).to be(true)
      expect(User.visible).not_to include(user)

      follow_redirect!
      page = Nokogiri::HTML(response.body)
      expect(page.at_css(".wb-title").text).to eq("Que bom que você voltou, Samuel!")
      expect(page.at_css(".wb-text").text.squish)
        .to eq("Sua conta ainda está congelada. Descongele para voltar a aparecer no mapa e continuar suas conversas.")
      expect(page.at_css(".wb-kept").text).to eq("Tudo ficou guardado do jeitinho que você deixou")
      expect(page.css(".wb-chips li").map { |li| li.text.squish }).to eq(%w[Fotos Conversas Favoritos])
      expect(page.at_css('form[action="/conta/descongelar"] button').text.squish).to eq("Descongelar conta")
      expect(page.at_css('form[action="/conta/congelada/sair"] button').text).to eq("Agora não, sair")
      expect(page.at_css(".sidebar")).to be_nil
    end

    it "\"Descongelar conta\" volta a aparecer e mostra o aviso em Meu Perfil" do
      post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
      post "/conta/descongelar"

      expect(response).to redirect_to(my_profile_path)
      expect(user.reload.account_frozen?).to be(false)
      expect(User.visible).to include(user)
      follow_redirect!
      expect(response.body).to include("Que bom que você ficou!")
    end

    it "pelo app (POST /api/v1/login): não descongela e avisa que está congelada" do
      post "/api/v1/login", params: { email: user.email, password: "password123" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("user", "frozen")).to be(true)
      expect(user.reload.account_frozen?).to be(true)
    end
  end

  it "sem estar congelada, /conta/de-volta volta a Meu Perfil" do
    sign_in user, scope: :user
    get "/conta/de-volta"

    expect(response).to redirect_to(my_profile_path)
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

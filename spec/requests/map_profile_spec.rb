require "rails_helper"

# Mapa (/discover_3d): prévia do pin (dados de /users/nearby) e folha do perfil completo
# (GET /users/:id?context=map → users/_full_profile com in_map, aberto pelo map_3d.js).
RSpec.describe "Perfil no mapa", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:user)  { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:other) do
    create(:user, onboarding_completed: true, plan: free_plan, username: "Luan Victor", verified: true,
                  birthdate: 32.years.ago.to_date - 20.days, gender: "Homem", interested_in: "Mulheres",
                  bio: "Advogado, apaixonado por livros.")
      .tap { |u| u.update_columns(city: "Salvador", state: "BA") }
  end

  before { sign_in user, scope: :user }

  describe "GET /users/:id?context=map" do
    it "devolve só o perfil (sem layout), na variante do mockup do mapa" do
      get "/users/#{other.id}", params: { context: "map" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("<html")
      page = Nokogiri::HTML(response.body)
      profile = page.at_css(".user-profile.is-in-map")
      expect(profile["data-user-id"]).to eq(other.id.to_s)
      expect(profile["data-controller"]).to be_nil # nada do "voltar" da página /users/:id

      expect(page.at_css(".up-handle")).to be_present
      expect(page.at_css("button.up-close[data-map-profile-close]")).to be_present
      expect(page.at_css(".up-fav form")["action"]).to eq("/favorites?favorited_user_id=#{other.id}")
      expect(page.at_css("a.up-gift")["href"]).to eq("/mimos/catalogo?receiver_id=#{other.id}")
      expect(page.at_css(".up-name strong").text).to eq("Luan Victor")
      expect(page.at_css(".up-age").text).to eq("32")
      # "~2 km de você · cidade": o JS preenche a distância; a cidade já vem (escondido sem cidade)
      place = page.at_css("[data-map-profile-distance]")
      expect(place.at_css(".up-place-dist").text).to eq("")
      expect(place.key?("hidden")).to eq(place.at_css(".up-place-city").nil?)

      pass = page.at_css(".up-pass").ancestors("form").first
      expect(pass["action"]).to eq("/lead/reject?source=map&user_id=#{other.id}")
      expect(pass["data-map-profile-dismiss"]).to eq("true")
      # Curtir: coração que curte e desfaz por alguns segundos (like_toggle_controller.js)
      like = page.at_css("button.up-like.like-toggle")
      expect(like["data-controller"]).to eq("like-toggle")
      expect(like["data-like-toggle-user-id-value"]).to eq(other.id.to_s)
      expect(like["data-like-toggle-liked-value"]).to eq("false")
      expect(page.at_css(".up-message").text.squish).to eq("Mensagem")

      expect(page.css(".up-label").map(&:text)).to eq([ "Sobre mim", "Em resumo" ])
      expect(page.css(".up-rows li").map { |li| li.text.squish }).to eq([ "Mora em Salvador, BA" ])
      expect(page.css(".up-safety-btn").map { |b| b.text.squish }).to eq(%w[Denunciar Bloquear])
      expect(page.at_css("#upgrade-modal-container")).to be_nil # a página do mapa já tem o dela
    end

    it "já curtido e favoritado: coração marcado e estrela cheia" do
      Like.create!(liker_id: user.id, liked_id: other.id, created_at: 1.minute.ago)
      user.favorites.create!(favorited_user: other)
      get "/users/#{other.id}", params: { context: "map" }
      page = Nokogiri::HTML(response.body)

      like = page.at_css("button.up-like.like-toggle")
      expect(like["data-like-toggle-liked-value"]).to eq("true")
      expect(like["data-like-toggle-undo-seconds-value"]).to eq("0") # curtida antiga: já vale
      expect(page.at_css(".up-fav .card-action-star--active")).to be_present
    end

    it "perfil indisponível (bloqueio, modo oculto, congelado, inexistente): 404 em vez de redirecionar" do
      other.update_columns(invisible: true)
      get "/users/#{other.id}", params: { context: "map" }
      expect(response).to have_http_status(:not_found)

      get "/users/0", params: { context: "map" }
      expect(response).to have_http_status(:not_found)

      get "/users/#{other.id}" # a página normal continua redirecionando
      expect(response).to redirect_to(discover_3d_path)
    end
  end

  describe "GET /users/nearby" do
    let(:origin) { [ -14.7876, -39.2781 ] }

    it "marca quem a pessoa já curtiu (coração da prévia do pin)" do
      other.update_columns(latitude: origin[0] + 0.0006, longitude: origin[1],
                           last_location_updated_at: Time.current, last_seen_at: Time.current)
      get "/users/nearby", params: { latitude: origin[0], longitude: origin[1], range: 300 }
      expect(response.parsed_body.find { |u| u["id"] == other.id }["liked"]).to be(false)

      Like.create!(liker_id: user.id, liked_id: other.id)
      get "/users/nearby", params: { latitude: origin[0], longitude: origin[1], range: 300 }
      expect(response.parsed_body.find { |u| u["id"] == other.id }["liked"]).to be(true)
    end
  end
end

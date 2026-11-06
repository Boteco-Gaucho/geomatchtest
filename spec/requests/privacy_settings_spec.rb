require "rails_helper"

RSpec.describe "Privacidade e localização (/privacidade)", type: :request do
  let!(:free) { create(:plan, :free) }
  let!(:gold) do
    create(:plan, code: "gold", name: "Gold", price_cents: 4799,
                  features: { "allow_invisible" => true, "unlimited_messages" => true })
  end

  # Praça de Itabuna/BA; ~0,0009° de latitude ≈ 100 m
  let(:origin) { [ -14.7876, -39.2781 ] }

  def place(user, lat_offset_m: 0, online: true)
    user.update_columns(latitude: origin[0] + lat_offset_m / 111_320.0, longitude: origin[1],
                        last_seen_at: Time.current,
                        last_location_updated_at: online ? Time.current : 1.hour.ago)
    user
  end

  def nearby(range: 300)
    get "/users/nearby", params: { latitude: origin[0], longitude: origin[1], range: range }
    expect(response).to have_http_status(:ok)
    JSON.parse(response.body)
  end

  let(:user) { create(:user, onboarding_completed: true, plan: free) }

  before { sign_in user, scope: :user }

  describe "GET /privacidade" do
    it "monta a tela do mockup: resumo, controles com o estado atual, política em tópicos e contato" do
      user.update_columns(invisible: false, share_location: nil)

      get "/privacidade"
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".prv-back")["href"]).to eq("/meu-perfil")
      expect(page.at_css(".prv-title").text.squish).to eq("Privacidade e localização")
      expect(page.css(".prv-summary li strong").map(&:text))
        .to eq([ "Sua posição nunca é exata", "Só quem está perto te vê", "Você decide quando aparecer" ])

      controls = page.css(".prv-control")
      expect(controls.map { |c| c.at_css("strong").text.squish })
        .to eq([ "Localização em tempo real", "Modo oculto no mapa Gold", "Oculto em Explorar cidades Gold", "Esconder minha idade Gold" ])
      expect(controls.map { |c| c["data-privacy-toggle-url-value"] })
        .to eq([ "/privacidade/localizacao", "/users/toggle_visibility", "/discover_3d/gallery/visibility", "/privacidade/idade" ])
      expect(controls.map { |c| c.at_css("button.prv-switch")["aria-checked"] }).to eq(%w[true false false false])

      topics = page.css(".prv-policy details")
      expect(topics.size).to eq(8)
      expect(topics.map { |d| d.key?("open") }).to eq([ false, true, false, false, false, false, false, false ])
      expect(topics[1].css("li strong").map(&:text)).to eq([ "Cadastro:", "Perfil:", "Localização:", "Uso do app:" ])
      expect(page.at_css(".prv-updated").text).to eq("Atualizada em 04/11/2026")
      expect(page.at_css("a.prv-full-policy")["href"]).to eq("/politica-de-privacidade")
      expect(page.at_css(".prv-note a")["href"]).to start_with("mailto:suporte@geomatch.com.br")
      expect(page.at_css("#upgrade-modal-container")).to be_present
    end

    it "pede login" do
      sign_out :user
      get "/privacidade"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /privacidade/localizacao" do
    it "desliga: tira do mapa de todo mundo na hora e para de gravar a posição" do
      place(user)

      expect { post "/privacidade/localizacao" }
        .to have_broadcasted_to("map_updates").with(action: "leave", user_id: user.id)
      expect(JSON.parse(response.body)).to eq("share_location" => false)
      expect(user.reload.share_location).to be(false)

      post "/users/update_location", params: { latitude: -14.7, longitude: -39.2 }, as: :json
      expect(user.reload.latitude.to_f).to eq(origin[0])
    end

    it "liga de novo" do
      user.update_columns(share_location: false)
      post "/privacidade/localizacao"
      expect(JSON.parse(response.body)).to eq("share_location" => true)
    end
  end

  describe "POST /privacidade/idade" do
    it "no Free: 403 pedindo o Gold, sem mudar nada" do
      post "/privacidade/idade"
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to include("upgrade_required" => true)
      expect(user.reload.hide_age).to be(false)
    end

    it "no Gold: esconde a idade dos outros (e ela volta se o Gold acabar)" do
      user.update!(plan: gold, birthdate: Date.new(1995, 1, 1))

      post "/privacidade/idade"
      expect(JSON.parse(response.body)).to eq("hide_age" => true)
      expect(user.reload.public_age).to be_nil
      expect(user.age).to be > 18

      user.update!(plan: free)
      expect(user.public_age).to eq(user.age)
    end
  end

  describe "idade escondida nas telas" do
    it "some do perfil completo de quem escondeu; em Meu Perfil o interruptor mostra o estado" do
      other = create(:user, onboarding_completed: true, plan: gold, birthdate: Date.new(1990, 5, 5))
      get "/users/#{other.id}"
      expect(Nokogiri::HTML(response.body).at_css(".up-age")).to be_present

      other.update_columns(hide_age: true)
      get "/users/#{other.id}"
      expect(Nokogiri::HTML(response.body).at_css(".up-age")).to be_nil

      user.update!(plan: gold, birthdate: Date.new(1995, 1, 1))
      user.update_columns(hide_age: true)
      get "/meu-perfil"
      row = Nokogiri::HTML(response.body).at_css('.me-toggle-row[data-privacy-toggle-key-value="hide_age"]')
      expect(row["data-privacy-toggle-url-value"]).to eq("/privacidade/idade")
      expect(row.at_css("button.me-switch")["aria-checked"]).to eq("true")
      expect(response.body).to include("#{user.display_name.split.first}, #{user.age}") # a própria pessoa ainda vê
    end
  end

  describe "mapa (/users/nearby)" do
    let(:other) { create(:user, onboarding_completed: true, plan: free, birthdate: Date.new(1990, 5, 5)) }

    it "manda a posição aproximada, nunca a do GPS" do
      place(other, lat_offset_m: 120)

      found = nearby.find { |u| u["id"] == other.id }
      expect(found).to be_present
      expect([ found["latitude"], found["longitude"] ]).not_to eq([ other.latitude.to_f, other.longitude.to_f ])
      gap_m = Geocoder::Calculations.distance_between([ found["latitude"], found["longitude"] ],
                                                      [ other.latitude, other.longitude ]) * 1000
      expect(gap_m).to be < 110
      expect(found["distance_km"]).to be <= 0.3
      expect(found).not_to have_key("birthdate")
    end

    it "nunca passa de 300 m, mesmo pedindo um raio maior" do
      place(other, lat_offset_m: 500)
      expect(nearby(range: 5000).map { |u| u["id"] }).not_to include(other.id)
    end

    it "tira quem desligou a localização e esconde a idade de quem pediu (Gold)" do
      hidden = place(create(:user, onboarding_completed: true, plan: free), lat_offset_m: 50)
      hidden.update_columns(share_location: false)
      place(other, lat_offset_m: 50)
      other.update!(plan: gold)
      other.update_columns(hide_age: true)

      users = nearby
      expect(users.map { |u| u["id"] }).to eq([ other.id ])
      expect(users.first["age"]).to be_nil
    end

    it "quem está oculto vê o mapa a partir do GPS do pedido, sem gravar a posição" do
      user.update!(plan: gold)
      user.update_columns(invisible: true, latitude: nil, longitude: nil)
      place(other, lat_offset_m: 80)

      expect(nearby.map { |u| u["id"] }).to eq([ other.id ])
      expect(user.reload.latitude).to be_nil
    end

    it "em tempo real avisa só quem está até 300 m, com a posição aproximada" do
      near_user = place(create(:user, onboarding_completed: true, plan: free), lat_offset_m: 100)
      far_user  = place(create(:user, onboarding_completed: true, plan: free), lat_offset_m: 900)

      expect { nearby }
        .to have_broadcasted_to(MapChannel.user_stream(near_user.id))
        .with(a_hash_including(action: "update", user_id: user.id))
        .and have_broadcasted_to(MapChannel.user_stream(far_user.id)).exactly(0).times

      expect { nearby }.not_to have_broadcasted_to("map_updates")
    end
  end
end

require "rails_helper"

RSpec.describe "Favoritos (/favorites)", type: :request do
  let(:me) { create(:user, onboarding_completed: true) }

  # cidade/estado via update_columns: no create o Geocoder tentaria consultar o Nominatim
  def person(name, city: "Salvador", state: "BA")
    create(:user, username: name).tap { |user| user.update_columns(city: city, state: state) }
  end

  before { sign_in me, scope: :user }

  it "mostra o topo com a contagem, os cards (estrela e mensagem) e a dica" do
    maria = person("Maria Clara")
    joao  = person("João", city: "Recife", state: "PE")
    me.favorites.create!(favorited_user: maria)
    me.favorites.create!(favorited_user: joao)

    get "/favorites"
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".fv-title").text).to eq("Favoritos")
    expect(page.at_css("#favorites-count").text).to eq("2 perfis salvos")
    expect(page.css(".fv-card-name strong").map(&:text)).to eq([ "João", "Maria Clara" ]) # mais recente primeiro
    expect(page.css(".fv-card-place").map(&:text)).to eq([ "Recife, PE", "Salvador, BA" ])
    expect(page.at_css("#favorite-card-#{maria.id} a.fv-card-link")["href"]).to eq("/users/#{maria.id}")

    star_form = page.at_css("#favorite-card-#{maria.id} .fv-card-star form")
    expect(star_form["action"]).to eq("/favorites/#{me.favorites.find_by(favorited_user: maria).id}?source=favorites")
    expect(page.css("#favorite-card-#{maria.id} .fv-card-chat")).to be_present
    expect(page.css(".fv-card .card-action-fav")).to be_empty # sem curtir no card de Favoritos
    expect(page.at_css(".fv-hint").text.squish).to eq("Toque na estrela para tirar alguém dos favoritos.")
    expect(page.css(".fv-empty")).to be_empty
  end

  it "sem favoritos mostra o vazio com Explorar cidades" do
    get "/favorites"
    page = Nokogiri::HTML(response.body)

    expect(page.at_css("#favorites-count").text).to eq("Nenhum perfil salvo")
    expect(page.at_css(".fv-empty-title").text).to eq("Nenhum favorito ainda")
    expect(page.at_css(".fv-empty-btn")["href"]).to eq("/discover_3d/gallery")
    expect(page.css(".fv-card, .fv-hint")).to be_empty
  end

  it "não lista quem foi bloqueado nem quem foi banido" do
    visible  = person("Aparece")
    blocked  = person("Bloqueado")
    banned   = person("Banido")
    [ visible, blocked, banned ].each { |user| me.favorites.create!(favorited_user: user) }
    create(:block, blocker: me, blocked: blocked)
    banned.update_columns(banned_at: Time.current)

    get "/favorites"
    page = Nokogiri::HTML(response.body)

    expect(page.css(".fv-card-name strong").map(&:text)).to eq([ "Aparece" ])
    expect(page.at_css("#favorites-count").text).to eq("1 perfil salvo")
  end

  describe "DELETE /favorites/:id" do
    let(:turbo) { { "Accept" => "text/vnd.turbo-stream.html" } }

    it "na tela de Favoritos tira o card, refaz a contagem e mostra o vazio quando sai o último" do
      maria    = person("Maria Clara")
      joao     = person("João")
      favorite = me.favorites.create!(favorited_user: maria)
      me.favorites.create!(favorited_user: joao)

      delete "/favorites/#{favorite.id}", params: { source: "favorites" }, headers: turbo
      expect(response.body).to include(%(<turbo-stream action="remove" target="favorite-card-#{maria.id}">))
      expect(response.body).to include("1 perfil salvo")
      expect(response.body).not_to include("fv-empty")

      delete "/favorites/#{me.favorites.sole.id}", params: { source: "favorites" }, headers: turbo
      expect(response.body).to include("Nenhum perfil salvo")
      expect(response.body).to include(%(target="favorites-body"))
      expect(response.body).to include("Nenhum favorito ainda")
      expect(me.favorites.count).to eq(0)
    end

    it "fora de Favoritos só troca a estrela" do
      maria    = person("Maria Clara")
      favorite = me.favorites.create!(favorited_user: maria)

      delete "/favorites/#{favorite.id}", headers: turbo

      expect(response.body).to include(%(<turbo-stream action="replace" target="favorite-btn-#{maria.id}">))
      expect(response.body).not_to include("favorite-card-")
    end
  end
end

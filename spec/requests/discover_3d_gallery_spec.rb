require "rails_helper"

RSpec.describe "Explorar cidades (/discover_3d/gallery)", type: :request do
  let(:gold) { create(:plan, code: "gold", name: "Gold", features: { "allow_invisible" => true }) }
  let(:me)   { create(:user, onboarding_completed: true) }

  # cidade/estado via update_columns: no create o Geocoder tentaria consultar o Nominatim
  def person(name, **attrs)
    create(:user, username: name, **attrs).tap { |user| user.update_columns(city: "Itabuna", state: "BA") }
  end

  before { sign_in me, scope: :user }

  it "monta a tela do mockup: topo, estado/cidade, capitais, gênero, contagem e cards" do
    person("Felipe Alves")

    get "/discover_3d/gallery", params: { state: "BA", city: "Itabuna" }
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".ce-title-text").text).to eq("Explorar cidades")
    expect(page.at_css(".ce-gold-badge").text).to eq("GOLD")
    expect(page.at_css(".ce-eye")["data-city-visibility-hidden-value"]).to eq("false")
    expect(page.at_css("select[name=state] option[selected]")["value"]).to eq("BA")

    lists = page.css(".ce-capitals-list")
    expect(lists.size).to eq(2) # a segunda cópia emenda o carrossel
    expect(lists.first.css("a").map(&:text).first(5)).to eq(%w[Rio\ Branco Maceió Macapá Manaus Salvador])
    expect(lists.first.css("a").size).to eq(27)
    expect(lists.last["aria-hidden"]).to eq("true")

    expect(page.css(".ce-segment-opt span").map(&:text)).to eq([ "Todos", "Homens", "Mulheres", "Não binário" ])
    expect(page.at_css(".ce-count").text.squish).to eq("1 pessoa em Itabuna")
    expect(page.at_css(".ce-favorites")["href"]).to eq("/favorites")
    expect(page.css(".profile-card").size).to eq(1)
    expect(page.at_css(".profile-card-name strong").text).to eq("Felipe Alves")
  end

  it "não mostra quem se ocultou da busca por cidades" do
    person("Aparece")
    person("Oculto", hidden_from_city_search: true)

    get "/discover_3d/gallery", params: { state: "BA" }

    names = Nokogiri::HTML(response.body).css(".profile-card-name strong").map(&:text)
    expect(names).to eq([ "Aparece" ])
  end

  describe "POST /discover_3d/gallery/visibility (olho de Explorar cidades)" do
    it "sem Gold responde 403 com upgrade_required" do
      post "/discover_3d/gallery/visibility", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include("upgrade_required" => true)
    end

    it "com Gold some e volta só da busca por cidades — o modo oculto do mapa não muda" do
      me.update!(plan: gold)

      post "/discover_3d/gallery/visibility", as: :json
      expect(response.parsed_body).to eq("hidden" => true)
      expect(me.reload).to have_attributes(hidden_from_city_search: true, invisible: false)
      expect(User.visible).to include(me) # continua no mapa

      post "/discover_3d/gallery/visibility", as: :json
      expect(response.parsed_body).to eq("hidden" => false)
      expect(me.reload.hidden_from_city_search).to be(false)
    end

    it "sem a coluna nova em produção, responde 503 e a galeria continua abrindo" do
      me.update!(plan: gold)
      allow(User).to receive(:city_search_hiding?).and_return(false)

      post "/discover_3d/gallery/visibility", as: :json
      expect(response).to have_http_status(:service_unavailable)

      get "/discover_3d/gallery"
      expect(response).to have_http_status(:ok)
    end
  end
end

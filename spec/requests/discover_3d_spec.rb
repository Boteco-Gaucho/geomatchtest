require "rails_helper"

RSpec.describe "Mapa (/discover_3d)", type: :request do
  let(:me) { create(:user, onboarding_completed: true, latitude: -12.9905, longitude: -38.456) }

  before { sign_in me, scope: :user }

  it "monta os controles do mockup que o map_3d.js usa" do
    get "/discover_3d"
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)

    expect(page.at_css(".radar-control-floating #range-value-text")).to be_present
    expect(page.at_css("#radar-range")["max"]).to eq("300")

    expect(page.css(".map-fab-container > .fab-button").map { |b| b["aria-label"] })
      .to eq([ "Visibilidade em tempo real", "Modo oculto", "Centralizar no meu local", "Busca por cidade" ])
    expect(page.at_css("#fab-live-tracking .icon-on")).to be_present
    expect(page.at_css("#fab-live-tracking .icon-off")).to be_present
    expect(page.at_css("#toggle-visibility-btn .eye-closed")["class"]).to include("hidden")
    expect(page.at_css(".fab-gallery")["href"]).to eq("/discover_3d/gallery")

    toast = page.at_css("#map-toast")
    expect(toast["hidden"]).not_to be_nil
    expect(toast.at_css(".map-toast__title")).to be_present
    expect(toast.at_css("button.map-toast__action")).to be_present
  end

  describe "POST /users/toggle_visibility (botão do olho)" do
    it "sem Gold responde 403 com upgrade_required — o mapa mostra o aviso \"Ver Gold\"" do
      post "/users/toggle_visibility", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to include("upgrade_required" => true)
      expect(me.reload.invisible).to be_falsey
    end

    it "com Gold liga e desliga o modo oculto" do
      me.update!(plan: create(:plan, code: "gold", name: "Gold", features: { "allow_invisible" => true }))

      post "/users/toggle_visibility", as: :json
      expect(response.parsed_body).to include("invisible" => true)

      post "/users/toggle_visibility", as: :json
      expect(response.parsed_body).to include("invisible" => false)
    end
  end
end

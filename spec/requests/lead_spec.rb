require "rails_helper"

RSpec.describe "Lead (/lead)", type: :request do
  # Localização por coordenadas, sem endereço: o Geocoder não consulta o Nominatim
  let(:me) { create(:user, onboarding_completed: true, latitude: -12.9714, longitude: -38.5014) }
  let(:brenda) do
    create(:user, username: "Brenda Souza", gender: "Mulher", birthdate: 26.years.ago.to_date - 20.days,
                  verified: true, bio: "Adoro conhecer novas amizades.", hobbies: "Praia,Cinema,Trilhas,Pets",
                  latitude: -12.9705, longitude: -38.5014) # ~100 m de me
  end

  def open_lead(candidate, distance = 0.1)
    allow_any_instance_of(AdvancedDiscoveryService).to receive(:find_next_eligible_user).and_return([ candidate, distance ])
    sign_in me, scope: :user
    get "/lead"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  it "monta o card do mockup: nome, idade, selo, online, distância, bio e até 3 interesses" do
    brenda.update_columns(last_seen_at: Time.current)

    card = open_lead(brenda).at_css(".lead-card")

    expect(card.at_css(".lead-name strong").text).to eq("Brenda")
    expect(card.at_css(".lead-name span").text).to eq("26")
    expect(card.at_css(".lead-verified")).to be_present
    expect(card.at_css(".lead-online").text).to eq("Ativa agora")
    expect(card.at_css(".lead-place").text.squish).to eq("Menos de 300 m de você")
    expect(card.at_css(".lead-bio").text).to eq("Adoro conhecer novas amizades.")
    expect(card.css(".lead-tags li").map(&:text)).to eq(%w[Praia Cinema Trilhas])
    expect(card.at_css("button.lead-open-profile")["data-action"]).to eq("lead-swipe#openProfile")
  end

  it "mantém a logo, tira o botão de tema e mostra os 4 botões de ação" do
    page = open_lead(brenda)

    expect(page.at_css(".geomatch-header img.header-logo")["src"]).to include("logo-geomatch-dourada")
    expect(page.css('.geomatch-header [data-controller="theme"]')).to be_empty
    expect(page.at_css(".geomatch-header .lead-filter-btn")["data-action"]).to eq("click->filters#open")
    expect(page.css(".lead-actions .lead-btn").map { |button| button["aria-label"] })
      .to eq([ "Desfazer", "Passar", "Mandar mensagem", "Curtir" ])
    expect(page.at_css(".lead-actions #rewind-flash")).to be_present
  end

  it "offline não mostra \"Ativa agora\"; mais longe mostra a distância aproximada" do
    brenda.update_columns(last_seen_at: 1.hour.ago, latitude: -12.9606) # ~1,2 km

    card = open_lead(brenda, 1.2).at_css(".lead-card")

    expect(card.at_css(".lead-online")).to be_nil
    expect(card.at_css(".lead-place").text.squish).to eq("~1,2 km de você")
  end
end

require "rails_helper"

# Editar perfil — Lugares que eu curto, O que você procura, Mais sobre você, Estilo de vida
RSpec.describe "Editar perfil: mais sobre você", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let(:me) { create(:user, onboarding_completed: true, plan: free_plan, city: nil) }

  before { sign_in me, scope: :user }

  def save(user_params, **extra)
    patch "/profile", params: { user: { bio: "Oi" }.merge(user_params) }.merge(extra)
    me.reload
  end

  it "o formulário traz as seções na ordem do mockup" do
    get "/profile/edit"
    page = Nokogiri::HTML(response.body)
    titles = page.css(".pe-card-title").map(&:text)
    expect(titles.last(6)).to eq([ "Interesses", "Lugares que eu curto", "Perguntas para puxar assunto",
                                   "O que você procura", "Mais sobre você", "Estilo de vida" ])
    expect(page.css("#pe-mais-sobre input[name='user[occupation]']").map { |i| i["value"] }).to include("Advogado(a)", "Prefiro não informar")
    expect(page.at_css("#pe-lugares")["data-chip-group-max-value"]).to eq("5")
  end

  it "salva tudo, com no máximo 5 lugares e só opções da lista" do
    save({ looking_for: "Algo casual", height_cm: "178", occupation: "Dentista", education_level: "masters_doctorate",
           zodiac_sign: "Leão", drinking: "Bebo sim", smoking: "Às vezes", pets: "Tenho gato", kids: "Quero ter",
           languages: [ "", "Português", "Klingon" ], exercise: [ "", "Yoga", "Bike" ],
           favorite_places: [ "", "Praia", "Shows", "Pagode", "Forró", "Samba", "Teatro", "Praia" ] })

    expect(me).to have_attributes(looking_for: "Algo casual", height_cm: 178, occupation: "Dentista",
                                  education_level: "masters_doctorate", zodiac_sign: "Leão", drinking: "Bebo sim",
                                  smoking: "Às vezes", pets: "Tenho gato", kids: "Quero ter",
                                  languages: [ "Português" ], exercise: %w[Yoga Bike])
    expect(me.favorite_places).to eq(%w[Praia Shows Pagode Forró Samba])
  end

  it "\"Prefiro não informar\" vale sozinho, a altura 0 e o texto livre da profissão" do
    save({ languages: [ "Português", "Prefiro não informar" ], height_cm: "0", occupation: "Dentista",
           occupation_other: "Fisioterapeuta", education_level: "education_not_informed" })

    expect(me.languages).to eq([ "Prefiro não informar" ])
    expect(me.height_cm).to eq(0)
    expect(me.occupation).to eq("Fisioterapeuta")
    expect(me.education_level).to eq("education_not_informed")
  end

  it "não aceita opção inventada" do
    save({ drinking: "Todo dia", bio: "não muda" })

    expect(response).to have_http_status(:unprocessable_entity)
    expect(me.drinking).to be_nil
  end
end

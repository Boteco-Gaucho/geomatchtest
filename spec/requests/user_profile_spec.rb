require "rails_helper"

RSpec.describe "Perfil de uma pessoa (/users/:id)", type: :request do
  let(:full_plan) { create(:plan, features: { "likes_right_unlimited" => true }) }
  let(:me)        { create(:user, onboarding_completed: true, plan: full_plan) }

  # cidade/estado via update_columns: no create o Geocoder tentaria consultar o Nominatim
  def person(name = "Felipe Alves", **attrs)
    create(:user, username: name, birthdate: 35.years.ago.to_date - 40.days, **attrs).tap do |user|
      user.update_columns(city: "Itabuna", state: "BA")
    end
  end

  def open_profile(user)
    get "/users/#{user.id}"
    expect(response).to have_http_status(:ok)
    Nokogiri::HTML(response.body)
  end

  before do
    allow(NotificationBroadcastJob).to receive(:perform_later)
    sign_in me, scope: :user
  end

  it "monta a tela do mockup: foto, nome, ações, Sobre mim/Em resumo/Interesses, Mandar mensagem e Denunciar | Bloquear" do
    felipe = person(verified: true, bio: "O cara da TI", gender: "Homem", interested_in: "Mulher",
                    hobbies: "Praia,Cinema,Viagem", last_seen_at: Time.current)

    page = open_profile(felipe)

    expect(page.at_css(".up-hero.is-empty .up-placeholder")).to be_present # sem foto: silhueta
    expect(page.at_css(".up-online").text.squish).to eq("Online agora")
    expect(page.at_css(".up-name strong").text).to eq("Felipe")
    expect(page.at_css(".up-age").text).to eq("35")
    expect(page.at_css(".up-verified")).to be_present
    expect(page.at_css(".up-place").text.squish).to eq("Itabuna, BA")
    expect(response.body).not_to include("km de distância") # a tela antiga mostrava uma distância fixa

    pass = page.at_css("form[action^='/lead/reject']")
    expect(pass["action"]).to include("source=profile", "user_id=#{felipe.id}")
    expect(pass["data-action"]).to eq("submit->user-profile#pass")
    expect(page.at_css("form[action='/start_chat/#{felipe.id}'] .up-message").text.squish).to eq("Mandar mensagem")
    expect(page.at_css("form[action^='/likes']")["action"]).to include("source=profile")
    expect(page.at_css("#favorite-btn-#{felipe.id} form[action^='/favorites']")).to be_present

    expect(page.css(".up-label").map(&:text)).to eq([ "Sobre mim", "Em resumo", "Interesses" ])
    expect(page.at_css(".up-bio").text).to eq("O cara da TI")
    expect(page.css(".up-rows li").map { |li| li.text.squish }).to eq([ "Mora em Itabuna, BA" ])
    expect(page.css(".up-tags li").map { |li| li.text.squish }).to eq(%w[Praia Cinema Viagem])
    expect(page.at_css(".up-cta-wrap form[action='/start_chat/#{felipe.id}'] .up-cta").text.squish).to eq("Mandar mensagem")

    expect(page.at_css(".up-safety a[href='/report_incident?user_id=#{felipe.id}']").text.squish).to eq("Denunciar")
    expect(page.at_css(".up-safety button")["onclick"]).to include("/users/#{felipe.id}/block")
    expect(page.at_css("#upgrade-modal-container")).to be_present # modal de limite do plano Free
  end

  it "Em resumo, Estilo de vida, o que procura e lugares: na 3ª pessoa, profissão pelo gênero, sem o \"Prefiro não informar\"" do
    luan = person("Luan Victor", gender: "Homem", bio: "Advogado")
    luan.update_columns(looking_for: "Algo sério, mas vamos ver", occupation: "Advogado(a)", education_level: User.education_levels["postgraduate"],
                 height_cm: 178, zodiac_sign: "Leão", languages: %w[Português Inglês Espanhol],
                 favorite_places: %w[Praia Restaurante Cafeteria], drinking: "Socialmente", smoking: "Não fumo",
                 exercise: %w[Corrida Academia], pets: "Amo pets", kids: "Prefiro não informar")
    me.update_columns(hobbies: "praia,Viagens,Futebol")
    luan.update_columns(hobbies: "Praia,Viagens,Leitura")

    page = open_profile(luan)

    expect(page.at_css(".up-looking").text.squish).to eq("Algo sério, mas vamos ver")
    rows = page.css(".up-card").find { |card| card.at_css(".up-label").text == "Em resumo" }.css(".up-rows li").map { |li| li.text.squish }
    expect(rows).to eq([ "Profissão Advogado", "Escolaridade Pós-graduação", "Altura 1,78 m", "Signo Leão",
                         "Idiomas Português · Inglês · Espanhol", "Mora em Itabuna, BA" ])
    life = page.css(".up-card").find { |card| card.at_css(".up-label").text == "Estilo de vida" }.css(".up-rows li").map { |li| li.text.squish }
    expect(life).to eq([ "Bebida Socialmente", "Cigarro Não fuma", "Atividade física Corrida · Academia", "Pets Ama pets" ]) # Filhos: não informado
    places = page.css(".up-card").find { |card| card.at_css(".up-label").text == "Lugares que curto" }
    expect(places.css("li").map(&:text)).to eq(%w[Praia Restaurante Cafeteria])
    expect(page.at_css(".up-common").text).to eq("2 em comum com você")
    expect(page.css(".up-tags li.is-common").map { |li| li.text.squish }).to eq(%w[Praia Viagens])
  end

  it "profissão no feminino e no texto livre; não binário mostra o chip como está" do
    ana = person("Ana", gender: "Mulher")
    ana.update_columns(occupation: "Médico(a)")
    expect(open_profile(ana).css(".up-rows li").first.text.squish).to eq("Profissão Médica")

    ana.update_columns(occupation: "Fisioterapeuta")
    expect(open_profile(ana).css(".up-rows li").first.text.squish).to eq("Profissão Fisioterapeuta")

    sam = person("Sam", gender: "Não Binário")
    sam.update_columns(occupation: "Engenheiro(a)")
    expect(open_profile(sam).css(".up-rows li").first.text.squish).to eq("Profissão Engenheiro(a)")
  end

  it "sem bio, informações e interesses não mostra o cartão; offline não mostra 'Online agora'" do
    vazio = create(:user, username: "Vazio", last_seen_at: 1.hour.ago)

    page = open_profile(vazio)

    expect(page.at_css(".up-card")).to be_nil
    expect(page.at_css(".up-online")).to be_nil
    expect(page.at_css(".up-place")).to be_nil
  end

  it "quem já foi curtido ou favoritado aparece com o coração e a estrela marcados" do
    felipe = person
    Like.create!(liker: me, liked: felipe)
    me.favorites.create!(favorited_user: felipe)

    page = open_profile(felipe)

    heart = page.at_css(".up-like")
    expect(heart["class"]).to include("is-liked")
    # Escuro e tocável: avisa "Você já curtiu este usuário" (antes desabilitado, nada acontecia)
    expect(heart["disabled"]).to be_nil
    expect(heart["data-action"]).to eq("user-profile#alreadyLiked")
    expect(page.at_css("form[action^='/likes']")).to be_nil
    expect(page.at_css("#favorite-btn-#{felipe.id} .card-action-star--active")).to be_present
  end

  it "no próprio perfil não há X, mensagem, curtir, estrela nem Denunciar/Bloquear" do
    me.update_columns(bio: "Eu mesmo")

    page = open_profile(me)

    expect(page.at_css(".up-actions")).to be_nil
    expect(page.at_css(".up-fav")).to be_nil
    expect(page.at_css(".up-safety")).to be_nil
    expect(page.at_css(".up-bio").text).to eq("Eu mesmo")
  end

  it "perfil de quem eu bloqueei continua indisponível" do
    felipe = person
    Block.create!(blocker: me, blocked: felipe)

    get "/users/#{felipe.id}"

    expect(response).to redirect_to("/discover_3d")
  end

  describe "ações" do
    it "o X (source=profile) registra o 'agora não' e responde 200 para o JS voltar" do
      felipe = person

      post "/lead/reject", params: { user_id: felipe.id, source: "profile" }

      expect(response).to have_http_status(:ok)
      expect(Like.find_by(liker: me, liked: felipe).is_like).to be(false)
    end

    it "curtir pelo perfil volta para o perfil (antes ia para o Início)" do
      felipe = person

      post "/likes", params: { user_id: felipe.id, source: "profile" }

      expect(response).to redirect_to("/users/#{felipe.id}")
      expect(Like.find_by(liker: me, liked: felipe).is_like).to be(true)
    end
  end
end

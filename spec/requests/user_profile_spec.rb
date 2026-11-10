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

  it "monta a tela do mockup: foto, nome, ações, Sobre/Informações/Interesses e Denunciar | Bloquear" do
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

    expect(page.css(".up-label").map(&:text)).to eq(%w[Sobre Informações Interesses])
    expect(page.at_css(".up-bio").text).to eq("O cara da TI")
    expect(page.css(".up-facts li").map { |li| li.text.squish }).to eq([ "Homem", "Quer conhecer mulheres", "Itabuna, BA" ])
    expect(page.css(".up-tags li").map(&:text)).to eq(%w[Praia Cinema Viagem])

    expect(page.at_css(".up-safety a[href='/report_incident?user_id=#{felipe.id}']").text.squish).to eq("Denunciar")
    expect(page.at_css(".up-safety button")["onclick"]).to include("/users/#{felipe.id}/block")
    expect(page.at_css("#upgrade-modal-container")).to be_present # modal de limite do plano Free
  end

  it "mostra os rótulos certos para não binário e para quem quer conhecer todo mundo" do
    sam = person("Sam", gender: "Não Binário", interested_in: "Todos")

    facts = open_profile(sam).css(".up-facts li").map { |li| li.text.squish }

    expect(facts).to eq([ "Não binário", "Quer conhecer todo mundo", "Itabuna, BA" ])
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

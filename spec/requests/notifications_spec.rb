require "rails_helper"

RSpec.describe "Curtidas (/notifications)", type: :request do
  # A factory padrão de Plan usa "see_who_liked"; o código lê "see_who_liked_me".
  let(:full_plan) { create(:plan, features: { "see_who_liked_me" => true, "likes_right_unlimited" => true }) }
  let(:free_plan) { create(:plan, :free) }
  let(:me)        { create(:user, onboarding_completed: true, plan: full_plan) }

  before do
    allow(NotificationBroadcastJob).to receive(:perform_later)
  end

  def person(name)
    create(:user, username: name, onboarding_completed: true)
  end

  def liked_by(actor, recipient: me, at: Time.current)
    like = Like.create!(liker: actor, liked: recipient)
    Notification.create!(recipient: recipient, actor: actor, action: "curtiu seu perfil", notifiable: like, created_at: at)
  end

  def open_page(as: me)
    sign_in as, scope: :user
    get "/notifications"
    response.body
  end

  describe "lista de quem te curtiu" do
    it "mostra cada pessoa uma vez e deixa de fora bloqueados e o que não é curtida (ex.: Mimo)" do
      ana = person("Ana Souza")
      liked_by(ana, at: 2.days.ago)
      match = Match.create!(user: me, matched_user: ana, status: "matched")
      Notification.create!(recipient: me, actor: ana, action: "vocês deram match!", notifiable: match)

      bia = person("Bia Lima")
      liked_by(bia)
      Block.create!(blocker: me, blocked: bia)

      carla = person("Carla Dias")
      Notification.create!(recipient: me, actor: carla, action: "te enviou um Mimo", notifiable: carla)

      body = open_page

      expect(body.scan("data-notification-id=").size).to eq(1)
      expect(body).to include('<span class="likes-tab-count">1</span>')
      expect(body).to include("Ana")
      expect(body).not_to include("Bia")
      expect(body).not_to include("Carla")
    end

    it "mostra em \"Novas hoje\" só quem curtiu hoje" do
      liked_by(person("Ana Souza"))
      liked_by(person("Eva Rocha"), at: 3.days.ago)

      body = open_page
      today_strip = body[/<div class="likes-today">.*?<div class="likes-grid">/m]

      expect(today_strip).to include("1 nova")
      expect(today_strip).to include("Ana")
      expect(today_strip).not_to include("Eva")
      expect(body.scan("data-notification-id=").size).to eq(2)
    end
  end

  describe "coração de curtir de volta" do
    it "envia a curtida pela própria tela quando você ainda não curtiu a pessoa" do
      ana = person("Ana Souza")
      liked_by(ana)

      body = open_page

      expect(body).to match(%r{<form class="like-card-heart-form" method="post" action="/likes"})
      expect(body).to include(%(name="user_id" value="#{ana.id}"))
      expect(body).to include('name="source" value="likes"')
    end

    it "quem já virou match continua em \"Te curtiram\" e o coração leva para a conversa" do
      dani = person("Dani Alves")
      liked_by(dani)
      Like.create!(liker: me, liked: dani)
      match = Match.create!(user: me, matched_user: dani, status: "matched")

      body = open_page

      expect(body.scan("data-notification-id=").size).to eq(1)
      expect(body).to include(%(href="/matches/#{match.id}"))
      expect(body).to match(/class="like-card-heart is-liked"/)
      expect(body).not_to include('action="/likes"')
    end

    # Bug: A curtiu B antes; B curtiu A de volta (match). A abria "Te curtiram" e via
    # "Ninguém te curtiu ainda" — quem você já tinha curtido era tirado da lista.
    it "eu curti primeiro e a pessoa curtiu de volta (match): ela aparece na minha lista" do
      bia = person("Bia Lima")
      Like.create!(liker: me, liked: bia)
      Like.create!(liker: bia, liked: me)
      match = Match.create!(user: me, matched_user: bia, status: "matched")
      Notification.create!(recipient: me, actor: bia, action: "vocês deram match!", notifiable: match)

      body = open_page

      expect(body).not_to include("Ninguém te curtiu ainda")
      expect(body).to include("Bia")
      expect(body).to include('<span class="likes-tab-count">1</span>')
    end
  end

  describe "plano que não mostra quem curtiu" do
    let(:free_me) { create(:user, onboarding_completed: true, plan: free_plan, latitude: -14.7935, longitude: -39.2803) }
    let!(:gold)   do
      create(:plan, code: "gold", name: "Gold", price_cents: 4990, duration_months: 1,
                    features: { "see_who_liked_me" => true, "likes_right_unlimited" => true })
    end

    it "não revela ninguém: sem nome, sem \"Novas hoje\" e sem curtir de volta (o match mostraria a pessoa)" do
      liked_by(person("Ana Souza"), recipient: free_me)

      body = open_page(as: free_me)

      expect(body).not_to include("Ana")
      expect(body).not_to include("Novas hoje")
      expect(body).not_to include('action="/likes"')
      expect(body).not_to include("like-card-heart")
      expect(body).to include('data-action="likes-upsell#open"')
    end

    it "mostra só a distância aproximada no card borrado" do
      ana = person("Ana Souza")
      ana.update_columns(latitude: -14.7935 + 0.00135, longitude: -39.2803) # ~150 m
      liked_by(ana, recipient: free_me)

      body = open_page(as: free_me)

      expect(body).to include('<span class="like-card-distance-pill">~150 m</span>')
    end

    it "traz o painel de upgrade com a contagem e o preço real do Gold, indo direto ao checkout" do
      %w[Ana Bia Carla Dani].each { |name| liked_by(person("#{name} Teste"), recipient: free_me) }

      body = open_page(as: free_me)
      sheet = body[/<div class="likes-upsell".*?<\/div>\s*<\/div>\s*<\/div>/m]

      expect(sheet).to include("4 pessoas por perto curtiram você")
      expect(sheet).to include("+1")
      expect(sheet).to include("Com o Gold você vê a lista de quem curtiu você")
      expect(sheet).to include("R$ 49,90/mês · Cancele quando quiser")
      expect(sheet).to include(%(action="/checkout?plan_id=#{gold.id}"))
    end
  end

  it "não mostra o painel de upgrade para quem já pode ver quem curtiu" do
    liked_by(person("Ana Souza"))

    expect(open_page).not_to include("likes-upsell-panel")
  end

  describe "POST /likes vindo da tela de Curtidas (source=likes)" do
    let(:ana) { person("Ana Souza") }

    before { liked_by(ana) }

    it "dá match e, ao fechar o modal, volta para Curtidas" do
      sign_in me, scope: :user
      post "/likes", params: { user_id: ana.id, source: "likes" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('data-match-modal-dismiss-path-value="/notifications"')
      expect(Match.for_user(me.id).where(user_id: ana.id).or(Match.for_user(me.id).where(matched_user_id: ana.id))).to exist
    end

    it "se você já tinha curtido, volta para Curtidas (e não para o Início)" do
      Like.create!(liker: me, liked: ana)

      sign_in me, scope: :user
      post "/likes", params: { user_id: ana.id, source: "likes" }

      expect(response).to redirect_to("/notifications")
    end
  end

  # Bug: o X do perfil aberto em Curtidas não tirava a pessoa da lista, e o coração
  # não levava ao chat depois do match
  describe "X e coração no perfil aberto pela tela de Curtidas" do
    let(:ana) { person("Ana Souza") }

    before do
      liked_by(ana)
      sign_in me, scope: :user
      allow(PushNotificationJob).to receive(:perform_later)
    end

    it "X: registra o descarte e a pessoa some de \"Te curtiram\" (e não aparece em \"Você curtiu\")" do
      get "/notifications"
      expect(response.body).to include(%(id="like-card-#{ana.id}"))
      expect(Nokogiri::HTML(response.body).at_css('meta[name="turbo-cache-control"]')["content"]).to eq("no-cache")

      post "/lead/reject", params: { user_id: ana.id, source: "profile" }
      expect(response).to have_http_status(:ok)
      expect(Like.find_by(liker: me, liked: ana).is_like).to be(false)

      get "/notifications"
      page = Nokogiri::HTML(response.body)
      expect(page.at_css("#like-card-#{ana.id}")).to be_nil
      expect(page.at_css(".likes-tab-count")).to be_nil
      expect(page.css('[data-panel="sent"] .like-card')).to be_empty
    end

    it "coração no perfil: \"É um match!\" que abre a conversa sozinho; \"Agora não\" volta ao perfil" do
      post "/likes", params: { user_id: ana.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      match = Match.for_user(me.id).find_by("user_id = :id OR matched_user_id = :id", id: ana.id)
      expect(match).to be_present
      expect(response.body).to include("É UM MATCH!")
      expect(response.body).to include(%(data-match-modal-message-path-value="/matches/#{match.id}"))
      expect(response.body).to include(%(data-match-modal-auto-forward-value="#{LikesController::MATCH_AUTO_FORWARD_MS}"))
      expect(response.body).to include("Abrindo a conversa")
      expect(response.body).to include("Agora não")
      expect(response.body).to include(%(data-match-modal-dismiss-path-value="/users/#{ana.id}"))

      get "/notifications"
      expect(response.body).to include(%(id="like-card-#{ana.id}")) # virou match: continua, levando à conversa
      expect(response.body).to include(%(href="/matches/#{match.id}"))

      get "/users/#{ana.id}"
      profile = Nokogiri::HTML(response.body)
      expect(profile.at_css(%(button.up-like.is-liked[type="button"]))).to be_present          # escuro: já curtiu
      expect(profile.at_css(%(a.up-message[href="/matches/#{match.id}"]))).to be_present       # mensagem abre a conversa
    end

    it "coração no card da grade: tira o card na hora junto com o modal" do
      post "/likes", params: { user_id: ana.id, source: "likes" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response.body).to include(%(<turbo-stream action="remove" target="like-card-#{ana.id}">))
      expect(response.body).to include("É UM MATCH!")
    end

    it "coração depois de ter dado X: a curtida substitui o descarte e dá match" do
      post "/lead/reject", params: { user_id: ana.id, source: "profile" }

      post "/likes", params: { user_id: ana.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(Like.find_by(liker: me, liked: ana).is_like).not_to be(false)
      expect(response.body).to include("É UM MATCH!")
    end

    it "já conversavam (começaram pelo Mensagem do mapa): sem modal de match novo, vai para a conversa" do
      talk = Match.create!(user: me, matched_user: ana)
      talk.messages.create!(sender: ana, content: "oi")

      post "/likes", params: { user_id: ana.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html, text/html" }

      expect(response).to redirect_to("/matches/#{talk.id}")
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq("Curtida enviada! Vocês já estão conversando.")
      expect(Match.for_user(me.id).count).to eq(1)
    end

    it "já tinha curtido e é match: o coração leva para a conversa em vez de só avisar" do
      Like.create!(liker: me, liked: ana)
      match = Match.create!(user: me, matched_user: ana, status: "matched")

      post "/likes", params: { user_id: ana.id, source: "profile" }

      expect(response).to redirect_to("/matches/#{match.id}")
      expect(Like.where(liker: me, liked: ana).count).to eq(1) # sem duplicar
    end
  end

  # Coração do perfil (/users/:id): vermelho = ainda não curtiu; escuro = já curtiu
  describe "coração do perfil aberto por Curtidas" do
    let(:luan) { person("Luan Victor") }
    let(:sam)  { person("Sam Rocha") }

    before do
      sign_in me, scope: :user
      allow(PushNotificationJob).to receive(:perform_later)
    end

    def profile(user)
      get "/users/#{user.id}"
      Nokogiri::HTML(response.body)
    end

    it "ainda não curtiu: coração vermelho que curte (form) e \"Mandar mensagem\" pelo start_chat" do
      page = profile(sam)
      heart = page.at_css("#profile-like-#{sam.id} form[action^='/likes'] button.up-like")
      expect(heart).to be_present
      expect(heart["class"]).not_to include("is-liked")
      expect(page.at_css("#profile-like-#{sam.id} form")["data-action"]).to eq("submit->user-profile#like")
      expect(page.at_css("#profile-message-#{sam.id} form[action='/start_chat/#{sam.id}']")).to be_present
    end

    it "já curtiu (e é match, ex.: Luan): coração escuro que só avisa, e mensagem direto na conversa" do
      Like.create!(liker: luan, liked: me)
      Like.create!(liker: me, liked: luan)
      match = Match.create!(user: me, matched_user: luan, status: "matched")

      page = profile(luan)
      heart = page.at_css("#profile-like-#{luan.id} button.up-like.is-liked")
      expect(heart["type"]).to eq("button")
      expect(heart["data-action"]).to eq("user-profile#alreadyLiked")
      banner = page.at_css("#profile-like-#{luan.id} template[data-already-liked-template]").inner_html
      expect(banner).to include("Você já curtiu Luan", "Que tal dar o próximo passo e mandar uma mensagem?")
      expect(heart["disabled"]).to be_nil # antes: desabilitado, o toque não fazia nada
      expect(page.at_css("#profile-like-#{luan.id} form")).to be_nil
      expect(page.at_css("#profile-message-#{luan.id} a.up-message")["href"]).to eq("/matches/#{match.id}")
    end

    it "conversa começada pelo Mensagem, sem curtida sua: coração escuro com o aviso de conversa" do
      match = Match.create!(user: me, matched_user: sam)

      page = profile(sam)
      expect(page.at_css("#profile-like-#{sam.id} button.is-liked")).to be_present
      expect(page.at_css("#profile-like-#{sam.id} template").inner_html).to include("Vocês já estão conversando")
      expect(page.at_css("#profile-message-#{sam.id} a.up-message")["href"]).to eq("/matches/#{match.id}")
    end

    it "curtir sem match: o servidor confirma o coração escuro sem recarregar, com aviso" do
      post "/likes", params: { user_id: sam.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      stream = Nokogiri::HTML(response.body)
      expect(stream.at_css(%(turbo-stream[action="replace"][target="profile-like-#{sam.id}"]))).to be_present
      expect(response.body).to include('class="up-action up-like is-liked"')
      expect(response.body).to include("Curtida enviada!")
      expect(Like.positive.where(liker: me, liked: sam).count).to eq(1)
    end

    it "curtida repetida (outra aba): só o aviso \"Você já curtiu\", sem duplicar" do
      Like.create!(liker: me, liked: sam)

      post "/likes", params: { user_id: sam.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include("Você já curtiu Sam", "Que tal dar o próximo passo e mandar uma mensagem?")
      expect(response.body).to include("tt-toast--liked")
      expect(response.body).to include(%(target="profile-like-#{sam.id}"))
      expect(Like.where(liker: me, liked: sam).count).to eq(1)
    end

    it "limite de curtidas: modal de upgrade e o coração volta a vermelho" do
      allow_any_instance_of(User).to receive(:can_like?).and_return(false)

      post "/likes", params: { user_id: sam.id, source: "profile" },
                     headers: { "ACCEPT" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include(%(target="upgrade-modal-container"))
      replaced = Nokogiri::HTML(response.body).at_css(%(turbo-stream[target="profile-like-#{sam.id}"]))
      expect(replaced.inner_html).to include("form")
      expect(replaced.inner_html).not_to include("is-liked")
    end
  end

  # O número do rodapé (Curtidas) e o de Mensagens = pessoas novas na lista "Te curtiram"
  describe "contador de curtidas novas" do
    def badge
      get "/matches"
      Nokogiri::HTML(response.body).at_css("#likes-badge")
    end

    before { sign_in me, scope: :user }

    it "conta uma vez por pessoa, sem Mimo, bloqueados e descartados; abrir a aba zera só as curtidas" do
      ana = person("Ana Souza")
      liked_by(ana)
      match = Match.create!(user: me, matched_user: ana, status: "matched")
      Notification.create!(recipient: me, actor: ana, action: "vocês deram match!", notifiable: match) # Ana 2x
      bia = person("Bia Lima")
      liked_by(bia)
      Block.create!(blocker: me, blocked: bia)                                                       # bloqueada
      carla = person("Carla Dias")
      liked_by(carla)
      Like.create!(liker: me, liked: carla, is_like: false)                                          # descartada
      dani = person("Dani Alves")
      mimo = Notification.create!(recipient: me, actor: dani, action: "te enviou um Mimo", notifiable: dani) # Mimo

      expect(me.unseen_likes_count).to eq(1)
      expect(badge.text).to eq("1")
      expect(badge["hidden"]).to be_nil

      get "/notifications"
      expect(response.body.scan("data-notification-id=").size).to eq(1) # a lista mostra a mesma 1 pessoa

      expect(badge.key?("hidden")).to be(true)
      expect(mimo.reload.read_at).to be_nil # o Mimo continua não lido
    end

    it "o aviso em tempo real manda o número certo (sem renderizar o card no job)" do
      notification = liked_by(person("Ana Souza"))
      allow(NotificationChannel).to receive(:broadcast_to)

      NotificationBroadcastJob.perform_now(notification)

      expect(NotificationChannel).to have_received(:broadcast_to).with(me, { kind: "like", count: 1 })
    end
  end
end

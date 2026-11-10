require "rails_helper"

RSpec.describe "Mensagens (/matches)", type: :request do
  # Coordenadas sem endereço: o Geocoder não consulta o Nominatim
  let(:me) { create(:user, onboarding_completed: true, latitude: -12.9714, longitude: -38.5014) }

  def person(name, **attrs)
    create(:user, username: name, onboarding_completed: true, latitude: -12.9705, longitude: -38.5014, **attrs)
  end

  before do
    sign_in me, scope: :user
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  describe "GET /matches (lista)" do
    it "mostra novas conexões, não lidas, \"Sua vez\" e o status da sua última mensagem" do
      felipe = person("Felipe", verified: true, last_seen_at: Time.current)
      luan   = person("Luan Victor")
      fany   = person("Fany")

      talk = Match.create!(user: me, matched_user: felipe)
      talk.messages.create!(sender: felipe, content: "Vou sim")
      talk.messages.create!(sender: felipe, content: "Apenas pelo link")
      read = Match.create!(user: me, matched_user: luan)
      read.messages.create!(sender: me, content: "Ok", status: :read)
      Like.create!(liker_id: me.id, liked_id: fany.id, is_like: true)
      Like.create!(liker_id: fany.id, liked_id: me.id, is_like: true)
      Match.create!(user: me, matched_user: fany)

      get "/matches"
      page = Nokogiri::HTML(response.body)

      expect(page.at_css("img.header-title-img")["src"]).to include("texto-mensagen") # título de sempre
      expect(page.at_css("#conversations-search-input")["placeholder"]).to eq("Buscar conversa")
      expect(page.css(".recent-matches-section .match-name").map(&:text)).to eq(%w[Curtidas Fany])

      felipe_row = page.at_css("#match-row-#{talk.id}")
      expect(felipe_row["data-your-turn"]).to eq("true")
      expect(felipe_row.at_css(".conv-last-message").text.squish).to eq("Apenas pelo link")
      expect(felipe_row.at_css(".conv-unread").text).to eq("2")
      expect(felipe_row.at_css(".conv-verified")).to be_present
      expect(felipe_row.at_css(".msg-online")).to be_present

      luan_row = page.at_css("#match-row-#{read.id}")
      expect(luan_row["data-your-turn"]).to eq("false")
      expect(luan_row.at_css(".conv-last-message").text.squish).to eq("Você: Ok")
      expect(luan_row.at_css(".conv-check.is-read")).to be_present
      expect(luan_row.at_css(".conv-unread")).to be_nil

      expect(page.at_css("#conversations-your-turn-count").text).to eq("1")
    end
  end

  describe "GET /matches/:id (conversa)" do
    let(:felipe) { person("Felipe", gender: "Homem", verified: true, last_seen_at: Time.current) }
    let(:match)  { Match.create!(user: me, matched_user: felipe) }

    it "monta topo, aviso de segurança, chip da conexão, balões e campo" do
      match.messages.create!(sender: felipe, content: "Oi! Vi que você também curte praia")
      sent = match.messages.create!(sender: me, content: "Curto demais!", status: :read, read_at: Time.current)

      get "/matches/#{match.id}"
      page = Nokogiri::HTML(response.body)

      expect(page.at_css(".header-name-text").text).to eq("Felipe")
      expect(page.at_css(".header-status").text).to eq("Ativo agora")
      expect(page.at_css(".chat-safety-tip").text).to include("prefira um lugar público")
      expect(page.at_css(".date-separator.is-connection").text).to eq("Hoje")
      expect(page.at_css(".chat-connection-chip").text.squish).to eq("Vocês se conectaram a menos de 300 m")

      row = page.at_css("#msg-#{sent.id}")
      expect(row["class"]).to include("sent", "is-group-end")
      expect(row["data-status"]).to eq("read")
      expect(row["data-read-at"]).to be_present
      expect(row.at_css(".message-status.status-read")).to be_present

      expect(page.css("#chat-quick-replies")).to be_empty # já mandei mensagem: sem sugestões
      expect(page.at_css(".chat-plus-item")["href"]).to eq("/mimos/catalogo?receiver_id=#{felipe.id}")
      expect(page.at_css("#message-input")["placeholder"]).to eq("Mensagem")
    end

    it "sugestões de mensagem só até mandar a primeira (receber não conta)" do
      match.messages.create!(sender: felipe, content: "Oi! Vi que você também curte praia")

      get "/matches/#{match.id}"
      page = Nokogiri::HTML(response.body)
      expect(page.css(".chat-quick-reply").map(&:text)).to eq([ "Oi! Tudo bem?", "E aí, beleza?", "Como tá seu dia?" ])

      match.messages.create!(sender: me, content: "Oi! Tudo bem?")

      get "/matches/#{match.id}"
      expect(Nokogiri::HTML(response.body).css("#chat-quick-replies")).to be_empty
    end

    it "menu dos três pontinhos na ordem do mockup" do
      get "/matches/#{match.id}"
      page = Nokogiri::HTML(response.body)

      expect(page.css(".gm-chat-menu .gm-menu-row").map { |row| row.text.squish })
        .to eq([ "Ver perfil", "Silenciar notificações", "Limpar conversa", "Denunciar Felipe", "Bloquear Felipe" ])
    end

    it "não mostra mensagens que a pessoa apagou para si" do
      hidden = match.messages.create!(sender: felipe, content: "some daqui")
      hidden.hide_for!(me)

      get "/matches/#{match.id}"

      expect(response.body).not_to include("some daqui")
    end
  end

  # Bug: o número de não lidas da lista não zerava ao abrir a conversa (só contava como
  # lida a mensagem que aparecia na tela com o WebSocket já conectado)
  describe "não lidas zeram ao abrir a conversa" do
    let(:felipe) { person("Felipe") }
    let(:match)  { Match.create!(user: me, matched_user: felipe) }

    def unread_badge
      get "/matches"
      Nokogiri::HTML(response.body).at_css("#match-row-#{match.id} .conv-unread")&.text
    end

    it "abrir marca TODAS as recebidas como lidas (também as que ficam acima da tela) e avisa quem enviou" do
      received = 18.times.map { |i| match.messages.create!(sender: felipe, content: "msg #{i}") }
      mine = match.messages.create!(sender: me, content: "minha")
      expect(unread_badge).to eq("18")

      get "/matches/#{match.id}"

      expect(response).to have_http_status(:ok)
      expect(Message.where(id: received.map(&:id)).pluck(:status).uniq).to eq([ "read" ])
      expect(Message.where(id: received.map(&:id)).pluck(:read_at)).to all(be_within(5.seconds).of(Time.current))
      expect(mine.reload.status).to eq("sent") # as minhas não mudam
      expect(MatchChannel).to have_received(:broadcast_to)
        .with(match, hash_including(action: "status_update", status: "read", message_ids: match_array(received.map(&:id))))
      page = Nokogiri::HTML(response.body)
      expect(page.css(".message-row.received").map { |r| r["data-status"] }.uniq).to eq([ "read" ])
      expect(page.at_css("#chat-window")["data-read-url"]).to eq("/matches/#{match.id}/read")

      expect(unread_badge).to be_nil # de volta à lista: sem o número
    end

    it "lista e conversa não ficam no cache do Turbo (voltar busca o número atualizado)" do
      match.messages.create!(sender: felipe, content: "oi")
      get "/matches"
      expect(Nokogiri::HTML(response.body).at_css('meta[name="turbo-cache-control"]')["content"]).to eq("no-cache")
      get "/matches/#{match.id}"
      expect(Nokogiri::HTML(response.body).at_css('meta[name="turbo-cache-control"]')["content"]).to eq("no-cache")
    end

    it "pré-carregamento do Turbo (passar o mouse no link) não marca; o POST read do chat marca" do
      msg = match.messages.create!(sender: felipe, content: "oi")

      get "/matches/#{match.id}", headers: { "X-Sec-Purpose" => "prefetch" }
      expect(msg.reload.status).to eq("sent")
      expect(unread_badge).to eq("1")

      post "/matches/#{match.id}/read", headers: { "Accept" => "application/json" }
      expect(response.parsed_body).to eq("read" => 1)
      expect(msg.reload.status).to eq("read")
      expect(unread_badge).to be_nil

      post "/matches/#{match.id}/read", headers: { "Accept" => "application/json" }
      expect(response.parsed_body).to eq("read" => 0) # de novo: nada a fazer, sem novo aviso
      expect(MatchChannel).to have_received(:broadcast_to).with(match, hash_including(action: "status_update")).once
    end

    it "não marca conversa de outras pessoas" do
      stranger = Match.create!(user: person("Ana"), matched_user: felipe)
      msg = stranger.messages.create!(sender: felipe, content: "oi")

      post "/matches/#{stranger.id}/read", headers: { "Accept" => "application/json" }

      expect(msg.reload.status).to eq("sent")
    end
  end
end

require "rails_helper"

RSpec.describe "Perguntas do perfil", type: :request do
  let!(:free_plan) { create(:plan, :free) }
  let!(:gold_plan) do
    create(:plan, code: "gold", name: "Gold", price_cents: 4799, duration_months: 1,
                  features: { "see_who_liked_me" => true })
  end
  let(:luan) { create(:user, username: "Luan Victor", gender: "Homem", onboarding_completed: true, city: nil) }
  let(:prompt) do
    luan.update_columns(city: "Salvador", state: "BA")
    luan.profile_prompts.create!(question_key: "perfect_date", answer: "Pôr do sol no Farol da Barra e depois um acarajé.")
  end

  before do
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  def profile_of(user)
    get "/users/#{user.id}"
    Nokogiri::HTML(response.body)
  end

  describe "Editar perfil" do
    let(:me) { create(:user, onboarding_completed: true, plan: free_plan, city: nil) }

    before { sign_in me, scope: :user }

    it "salva até 3 perguntas da lista, ignorando vazias, repetidas e chaves que não existem" do
      patch "/profile", params: {
        user: { bio: "Oi" }, profile_prompts_submitted: "1",
        profile_prompts: {
          "0" => { key: "perfect_date", answer: "  Praia e acarajé  " },
          "1" => { key: "perfect_date", answer: "repetida" },
          "2" => { key: "hackeada", answer: "não existe" },
          "3" => { key: "hot_take", answer: "" },
          "4" => { key: "on_repeat", answer: "Caetano" },
          "5" => { key: "best_trip", answer: "Chapada" },
          "6" => { key: "ideal_sunday", answer: "passa do limite" }
        }
      }

      expect(me.profile_prompts.reload.map { |p| [ p.question_key, p.answer ] })
        .to eq([ %w[perfect_date Praia\ e\ acarajé], %w[on_repeat Caetano], %w[best_trip Chapada] ])
    end

    it "o formulário mostra 3 campos com a lista de perguntas" do
      get "/profile/edit"
      page = Nokogiri::HTML(response.body)
      expect(page.css("#pe-perguntas select").size).to eq(3)
      expect(page.css("#pe-perguntas select").first.css("option").map(&:text)).to include("Um encontro perfeito é…")
    end
  end

  describe "no perfil de outra pessoa" do
    it "quem não é Gold vê a pergunta e o Responder abre o aviso do Gold, com o preço real e o checkout" do
      me = create(:user, onboarding_completed: true, plan: free_plan)
      prompt
      sign_in me, scope: :user

      page = profile_of(luan)
      card = page.at_css("#profile_prompt_#{prompt.id}")
      expect(card.at_css(".up-prompt-question").text).to eq("Um encontro perfeito em Salvador é…")
      expect(card.at_css(".up-prompt-answer").text).to eq("Pôr do sol no Farol da Barra e depois um acarajé.")
      button = card.at_css("button.up-prompt-btn")
      expect(button["data-action"]).to eq("prompt-gold#open")
      expect(button["data-prompt-gold-question-param"]).to eq("Um encontro perfeito em Salvador é…")
      expect(card.at_css("form")).to be_nil

      modal = page.at_css(".pg-overlay[hidden]")
      expect(modal.at_css(".pg-title").text.squish).to eq("Responda perguntas com o Gold")
      expect(modal.at_css(".pg-text").text).to include("na resposta do Luan")
      expect(modal.css(".pg-perks li").map { |li| li.text.squish })
        .to eq([ "Responder perguntas dos perfis", "Ver quem curtiu você", "Mensagens ilimitadas", "Modo oculto no mapa" ])
      expect(modal.at_css("form.pg-cta-form")["action"]).to eq("/checkout?plan_id=#{gold_plan.id}")
      expect(modal.at_css(".pg-price").text).to eq("R$ 47,99/mês · cancele quando quiser")
    end

    it "quem é Gold vê o Responder que abre o campo ali mesmo" do
      me = create(:user, onboarding_completed: true, plan: gold_plan)
      prompt
      sign_in me, scope: :user

      page = profile_of(luan)
      card = page.at_css("#profile_prompt_#{prompt.id}")
      expect(card["data-controller"]).to eq("prompt-reply")
      expect(card.at_css("form.up-prompt-form")["action"]).to eq("/users/#{luan.id}/prompt_replies")
      expect(page.at_css(".pg-overlay")).to be_nil
    end

    it "no próprio perfil não há Responder" do
      prompt
      sign_in luan, scope: :user

      page = profile_of(luan)
      expect(page.at_css("#profile_prompt_#{prompt.id} .up-prompt-answer")).to be_present
      expect(page.at_css(".up-prompt-btn")).to be_nil
    end
  end

  describe "POST /users/:id/prompt_replies" do
    let(:stream) { { "ACCEPT" => "text/vnd.turbo-stream.html, text/html" } }

    it "Gold: cria a conversa (sem match), manda a resposta citando a pergunta, mostra Respondida e o aviso" do
      me = create(:user, onboarding_completed: true, plan: gold_plan)
      prompt
      sign_in me, scope: :user

      post "/users/#{luan.id}/prompt_replies",
           params: { prompt_key: "perfect_date", content: "Combinação perfeita! Conheço um acarajé ótimo ali perto 😄" },
           headers: stream

      match = Match.for_user(me.id).find_by("user_id = :id OR matched_user_id = :id", id: luan.id)
      message = match.messages.last
      expect(message).to have_attributes(sender_id: me.id, prompt_key: "perfect_date",
                                         prompt_question: "Um encontro perfeito em Salvador é…",
                                         prompt_answer: "Pôr do sol no Farol da Barra e depois um acarajé.")
      expect(MatchChannel).to have_received(:broadcast_to)
        .with(match, hash_including(message: hash_including(prompt: hash_including(question: "Um encontro perfeito em Salvador é…"))))

      body = Nokogiri::HTML(response.body)
      replaced = body.at_css(%(turbo-stream[action="replace"][target="profile_prompt_#{prompt.id}"]))
      expect(replaced.inner_html).to include("Respondida")
      expect(replaced.inner_html).to include("Conheço um acarajé ótimo")
      expect(response.body).to include("Resposta enviada")
      expect(response.body).to include(%(<span class="tt-badge">GOLD</span>))
      expect(response.body).to include("Luan recebe sua resposta como mensagem.")

      # De novo: sem segunda mensagem, e o perfil já mostra Respondida
      post "/users/#{luan.id}/prompt_replies", params: { prompt_key: "perfect_date", content: "outra" }, headers: stream
      expect(match.messages.count).to eq(1)
      expect(profile_of(luan).at_css("#profile_prompt_#{prompt.id} .up-prompt-done").text.squish).to eq("Respondida")

      # Na conversa, o balão traz a pergunta citada
      get "/matches/#{match.id}"
      bubble = Nokogiri::HTML(response.body).at_css("#msg-#{message.id} .msg-prompt")
      expect(bubble.at_css(".msg-prompt-question").text).to eq("Um encontro perfeito em Salvador é…")
      expect(bubble.at_css(".msg-prompt-label").text).to eq("Você respondeu a pergunta")
    end

    it "quem não é Gold não consegue responder" do
      me = create(:user, onboarding_completed: true, plan: free_plan)
      prompt
      sign_in me, scope: :user

      post "/users/#{luan.id}/prompt_replies", params: { prompt_key: "perfect_date", content: "Oi" }, headers: stream

      expect(response).to have_http_status(:forbidden)
      expect(Message.count).to eq(0)
      expect(Match.count).to eq(0)
    end

    it "não responde quem bloqueou, a si mesmo, pergunta inexistente ou resposta vazia" do
      me = create(:user, onboarding_completed: true, plan: gold_plan)
      prompt
      sign_in me, scope: :user

      post "/users/#{luan.id}/prompt_replies", params: { prompt_key: "best_trip", content: "Oi" }, headers: stream
      expect(response).to have_http_status(:not_found)

      post "/users/#{luan.id}/prompt_replies", params: { prompt_key: "perfect_date", content: "   " }, headers: stream
      expect(response).to have_http_status(:unprocessable_entity)

      Block.create!(blocker: luan, blocked: me)
      post "/users/#{luan.id}/prompt_replies", params: { prompt_key: "perfect_date", content: "Oi" }, headers: stream
      expect(response).to have_http_status(:not_found)
      expect(Message.count).to eq(0)
    end
  end
end

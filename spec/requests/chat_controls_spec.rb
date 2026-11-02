require "rails_helper"

# Menu da mensagem (Editar / Apagar para todos / Apagar para mim) e menu dos três
# pontinhos (Silenciar / Limpar conversa)
RSpec.describe "Controles do chat", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:me)    { create(:user, onboarding_completed: true) }
  let(:other) { create(:user, onboarding_completed: true) }
  let(:match) { Match.create!(user: me, matched_user: other) }
  let(:mine)  { match.messages.create!(sender: me, content: "Oi") }
  let(:theirs) { match.messages.create!(sender: other, content: "Olá") }

  before do
    sign_in me, scope: :user
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  describe "PATCH (Editar)" do
    it "edita a própria mensagem dentro de 15 min" do
      patch "/matches/#{match.id}/messages/#{mine.id}", params: { message: { content: "Oi, tudo bem?" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("content" => "Oi, tudo bem?")
      expect(mine.reload).to be_edited
    end

    it "não edita depois de 15 min" do
      mine
      travel 16.minutes do
        patch "/matches/#{match.id}/messages/#{mine.id}", params: { message: { content: "tarde" } }, as: :json
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(mine.reload.content).to eq("Oi")
    end

    it "não edita mensagem da outra pessoa" do
      patch "/matches/#{match.id}/messages/#{theirs.id}", params: { message: { content: "x" } }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE (Apagar para todos)" do
    it "apaga enquanto a outra pessoa não viu" do
      delete "/matches/#{match.id}/messages/#{mine.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(Message.exists?(mine.id)).to be(false)
    end

    it "apaga até 3 min depois de vista" do
      mine.update_columns(status: Message.statuses[:read], read_at: 2.minutes.ago)

      delete "/matches/#{match.id}/messages/#{mine.id}", as: :json

      expect(response).to have_http_status(:ok)
    end

    it "não apaga mais de 3 min depois de vista" do
      mine.update_columns(status: Message.statuses[:read], read_at: 5.minutes.ago)

      delete "/matches/#{match.id}/messages/#{mine.id}", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to include("3 minutos")
      expect(Message.exists?(mine.id)).to be(true)
    end

    it "não apaga mensagem da outra pessoa para todos" do
      delete "/matches/#{match.id}/messages/#{theirs.id}", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Message.exists?(theirs.id)).to be(true)
    end
  end

  it "POST hide (Apagar para mim): some só para quem apagou" do
    post "/matches/#{match.id}/messages/#{theirs.id}/hide", as: :json

    expect(response).to have_http_status(:ok)
    expect(Message.visible_to(me)).not_to include(theirs)
    expect(Message.visible_to(other)).to include(theirs)
  end

  it "DELETE clear_conversation (Limpar conversa): só para quem limpou" do
    mine
    theirs

    delete "/matches/#{match.id}/clear_conversation", as: :json

    expect(response).to have_http_status(:no_content)
    expect(match.messages.visible_to(me)).to be_empty
    expect(match.messages.visible_to(other).count).to eq(2)
  end

  it "PATCH mute (Silenciar notificações): liga e devolve o estado" do
    patch "/matches/#{match.id}/mute", as: :json

    expect(response.parsed_body).to eq("muted" => true)
    expect(match.reload.muted_for?(me)).to be(true)
  end

  # Antes qualquer usuário logado lia mensagens e reagia em conversas alheias pelo id
  describe "conversa de outras pessoas" do
    let(:stranger_match) { Match.create!(user: other, matched_user: create(:user)) }
    let!(:secret) { stranger_match.messages.create!(sender: other, content: "segredo") }

    it "não lista as mensagens" do
      get "/matches/#{stranger_match.id}/messages", as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "não deixa reagir" do
      post "/matches/#{stranger_match.id}/messages/#{secret.id}/react", params: { emoji: "👍" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(secret.reactions).to be_empty
    end
  end
end

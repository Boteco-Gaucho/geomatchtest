require "rails_helper"

# Curtir pelo mapa e desfazer dentro da janela (Like::UNDO_WINDOW) — like_toggle_controller.js
RSpec.describe "Curtir e desfazer (mapa)", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let!(:free_plan) { create(:plan, :free, features: { "likes_limit" => 47 }) rescue create(:plan, :free) }
  let(:user)  { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:other) { create(:user, onboarding_completed: true, plan: free_plan) }
  let(:json)  { { "Accept" => "application/json" } }

  before { sign_in user, scope: :user }

  def like!
    post "/likes", params: { user_id: other.id, source: "map" }, headers: json
    response.parsed_body
  end

  it "curtir responde com o id e o tempo para desfazer; a notificação só sai depois da janela" do
    data = nil
    expect { data = like! }.to change(Like, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(data["status"]).to eq("liked")
    expect(data["like_id"]).to eq(Like.last.id)
    expect(data["undo_seconds"]).to eq(Like::UNDO_WINDOW.to_i)

    job = enqueued_jobs.find { |j| j["job_class"] == "NotificationBroadcastJob" }
    expect(job).to be_present
    expect(job["scheduled_at"]).to be_present # adiada: quem desfaz não chega a notificar
  end

  it "dentro da janela, descurtir apaga a curtida e a notificação e devolve a curtida ao saldo" do
    data = like!
    expect(user.reload.likes_count).to eq(1)
    expect(Notification.where(recipient: other, actor: user)).to exist

    delete "/likes/#{data['like_id']}", headers: json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("unliked")
    expect(Like.where(liker: user, liked: other)).to be_empty
    expect(Notification.where(recipient: other, actor: user)).to be_empty
    expect(user.reload.likes_count).to eq(0)

    # pode curtir de novo, com uma janela nova
    expect(like!["status"]).to eq("liked")
  end

  it "depois da janela a curtida vale: descurtir é recusado" do
    data = like!

    travel(Like::UNDO_WINDOW + 1.second) do
      delete "/likes/#{data['like_id']}", headers: json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["undo_seconds"]).to eq(0)
      expect(Like.where(id: data["like_id"])).to exist

      # curtir de novo só devolve o estado (já vale)
      again = like!
      expect(again["like_id"]).to eq(data["like_id"])
      expect(again["undo_seconds"]).to eq(0)
    end
  end

  it "curtida que virou match não se desfaz" do
    Like.create!(liker: other, liked: user)
    data = like!
    expect(data["status"]).to eq("match")
    expect(data["match_path"]).to start_with("/matches/")

    like = Like.find_by(liker: user, liked: other)
    delete "/likes/#{like.id}", headers: json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Like.where(id: like.id)).to exist
  end

  it "não dá para desfazer a curtida de outra pessoa" do
    foreign = Like.create!(liker: other, liked: user)
    delete "/likes/#{foreign.id}", headers: json

    expect(response).to have_http_status(:not_found)
    expect(Like.where(id: foreign.id)).to exist
  end

  it "um \"agora não\" antigo não impede curtir pelo coração do mapa" do
    Like.create!(liker: user, liked: other, is_like: false)

    expect(like!["status"]).to eq("liked")
    expect(Like.find_by(liker: user, liked: other).is_like).not_to be(false)
  end

  it "a notificação de uma curtida desfeita é descartada sem erro quando o job roda" do
    data = like!
    delete "/likes/#{data['like_id']}", headers: json

    expect { perform_enqueued_jobs(only: NotificationBroadcastJob) }.not_to raise_error
  end
end

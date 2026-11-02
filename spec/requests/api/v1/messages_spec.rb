require "rails_helper"

RSpec.describe "Api::V1 mensagens (app Android)", type: :request do
  let(:me)    { create(:user) }
  let(:other) { create(:user) }
  let(:match) { Match.create!(user: me, matched_user: other) }
  let(:auth_headers) do
    { "Authorization" => "Bearer #{JwtService.encode({ sub: me.id })}", "Accept" => "application/json" }
  end

  before do
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  it "não devolve o que a pessoa apagou para si na web — nem na conversa nem na prévia da lista" do
    match.messages.create!(sender: other, content: "fica")
    match.messages.create!(sender: other, content: "some daqui").hide_for!(me)

    get "/api/v1/messages", params: { match_id: match.id }, headers: auth_headers
    expect(response.parsed_body["messages"].map { |message| message["content"] }).to eq([ "fica" ])

    get "/api/v1/matches", headers: auth_headers
    expect(response.parsed_body["matches"].first.dig("last_message", "content")).to eq("fica")
  end

  it "conversa limpa na web chega vazia no app" do
    match.messages.create!(sender: other, content: "antiga")
    match.clear_for!(me)

    get "/api/v1/messages", params: { match_id: match.id }, headers: auth_headers
    expect(response.parsed_body["messages"]).to eq([])
  end
end

require "rails_helper"

RSpec.describe MatchChannel, type: :channel do
  let(:me)    { create(:user) }
  let(:other) { create(:user) }
  let(:match) { Match.create!(user: me, matched_user: other) }

  before { allow(PushNotificationJob).to receive(:perform_later) }

  it "guarda e transmite o horário de leitura (\"Lida às…\" e o prazo do Apagar para todos)" do
    message = match.messages.create!(sender: other, content: "Oi")
    stub_connection current_user: me
    subscribe(match_id: match.id)

    expect { perform :mark_as_read, message_id: message.id }
      .to have_broadcasted_to(match).with(hash_including(action: "status_update", status: "read", read_at: anything))
    expect(message.reload).to have_attributes(status: "read", read_at: be_within(5.seconds).of(Time.current))
  end
end

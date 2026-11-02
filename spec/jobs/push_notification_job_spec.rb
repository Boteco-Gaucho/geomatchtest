require "rails_helper"

RSpec.describe PushNotificationJob, type: :job do
  let(:me)      { create(:user) }
  let(:other)   { create(:user) }
  let(:match)   { Match.create!(user: me, matched_user: other) }
  let(:message) do
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
    match.messages.create!(sender: other, content: "Oi")
  end

  it "não manda push de conversa silenciada" do
    match.toggle_mute!(me)
    job = described_class.new
    allow(job).to receive(:send_web_push)

    job.perform(message.id)

    expect(job).not_to have_received(:send_web_push)
  end

  it "manda push normalmente sem silenciar" do
    job = described_class.new
    allow(job).to receive(:send_web_push)
    allow(job).to receive(:send_apns)
    allow(job).to receive(:send_fcm)

    job.perform(message.id)

    expect(job).to have_received(:send_web_push).with(me, message.id, anything)
  end
end

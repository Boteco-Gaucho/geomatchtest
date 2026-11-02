require "rails_helper"

RSpec.describe Match, type: :model do
  # Coordenadas sem endereço: o Geocoder não consulta o Nominatim
  let(:me)    { create(:user, latitude: -12.9714, longitude: -38.5014) }
  let(:other) { create(:user, latitude: -12.9705, longitude: -38.5014) }
  let(:match) { Match.create!(user: me, matched_user: other) }

  before do
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  it "guarda a distância de quando a conexão aconteceu" do
    expect(match.distance_m).to be_between(90, 110)
  end

  it "sem localização de alguém, fica sem distância" do
    other.update_columns(latitude: nil)

    expect(match.distance_m).to be_nil
  end

  describe "#toggle_mute! (Silenciar notificações)" do
    it "liga e desliga só para quem pediu" do
      match.toggle_mute!(me)
      expect(match.reload.muted_for?(me)).to be(true)
      expect(match.muted_for?(other)).to be(false)

      match.toggle_mute!(me)
      expect(match.reload.muted_for?(me)).to be(false)
    end
  end

  describe "#clear_for! (Limpar conversa)" do
    it "as mensagens somem só para quem limpou" do
      match.messages.create!(sender: other, content: "Oi")
      match.messages.create!(sender: me, content: "Oi!")

      match.clear_for!(me)

      expect(match.messages.visible_to(me)).to be_empty
      expect(match.messages.visible_to(other).count).to eq(2)
    end
  end
end

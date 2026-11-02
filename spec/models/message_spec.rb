require "rails_helper"

RSpec.describe Message, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:me)    { create(:user) }
  let(:other) { create(:user) }
  let(:match) { Match.create!(user: me, matched_user: other) }
  let(:mine)  { match.messages.create!(sender: me, content: "Oi") }

  before do
    allow(MatchChannel).to receive(:broadcast_to)
    allow(PushNotificationJob).to receive(:perform_later)
  end

  describe "#deletable_for_everyone_by? (Apagar para todos)" do
    it "pode enquanto a outra pessoa não viu, mesmo muito tempo depois" do
      mine.update_columns(status: Message.statuses[:delivered], created_at: 2.days.ago)

      expect(mine.deletable_for_everyone_by?(me)).to be(true)
    end

    it "pode até 3 minutos depois de vista" do
      mine.update_columns(status: Message.statuses[:read], read_at: 2.minutes.ago)

      expect(mine.deletable_for_everyone_by?(me)).to be(true)
    end

    it "não pode mais de 3 minutos depois de vista" do
      mine.update_columns(status: Message.statuses[:read], read_at: 4.minutes.ago)

      expect(mine.deletable_for_everyone_by?(me)).to be(false)
    end

    it "lida antes de existir o horário de leitura conta como vista há muito tempo" do
      mine.update_columns(status: Message.statuses[:read], read_at: nil)

      expect(mine.deletable_for_everyone_by?(me)).to be(false)
    end

    it "só quem enviou" do
      expect(mine.deletable_for_everyone_by?(other)).to be(false)
    end
  end

  describe "#editable_by? (Editar)" do
    it "até 15 minutos depois de enviar, só quem enviou" do
      expect(mine.editable_by?(me)).to be(true)
      expect(mine.editable_by?(other)).to be(false)

      travel 16.minutes do
        expect(mine.editable_by?(me)).to be(false)
      end
    end
  end

  describe "#edit!" do
    it "troca o texto, marca como editada e avisa a conversa" do
      mine.edit!("Oi, tudo bem?")

      expect(mine.reload).to have_attributes(content: "Oi, tudo bem?", edited?: true)
      expect(MatchChannel).to have_received(:broadcast_to)
        .with(match, { edited_message: { id: mine.id, content: "Oi, tudo bem?", edited_at: mine.edited_at.iso8601 } })
    end
  end

  describe "#hide_for! (Apagar para mim)" do
    it "some só para quem apagou, sem repetir o id" do
      2.times { mine.hide_for!(me) }

      expect(Message.visible_to(me)).not_to include(mine)
      expect(Message.visible_to(other)).to include(mine)
      expect(mine.reload.hidden_for_user_ids).to eq([ me.id ])
    end
  end
end

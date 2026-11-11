require "rails_helper"

RSpec.describe WebhookEvent, type: :model do
  subject(:webhook_event) { build(:webhook_event) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:payload) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending processing processed failed]) }
  end

  describe "scopes" do
    it "pending returns only pending events" do
      pending_event = create(:webhook_event, status: "pending")
      _failed_event = create(:webhook_event, status: "failed")

      expect(described_class.pending).to include(pending_event)
      expect(described_class.pending.pluck(:status).uniq).to eq(["pending"])
    end

    it "failed returns only failed events" do
      failed_event = create(:webhook_event, status: "failed")
      _pending_event = create(:webhook_event, status: "pending")

      expect(described_class.failed).to include(failed_event)
      expect(described_class.failed.pluck(:status).uniq).to eq(["failed"])
    end

    it "payments returns only payment topic events" do
      payment_event = create(:webhook_event, topic: "payment")
      _other_event = create(:webhook_event, topic: "merchant_order")

      expect(described_class.payments).to include(payment_event)
      expect(described_class.payments.pluck(:topic).uniq).to eq(["payment"])
    end
  end

  describe "#mark_as_failed!" do
    it "sets status to failed, increments attempts and stores error" do
      event = create(:webhook_event, status: "pending", attempts: 0, processing_errors: nil)
      event.mark_as_failed!("boom")

      event.reload
      expect(event.status).to eq("failed")
      expect(event.attempts).to eq(1)
      expect(event.processing_errors).to eq("boom")
    end
  end

  describe "#mark_as_processed!" do
    it "sets status to processed, sets processed_at and clears errors" do
      event = create(:webhook_event, status: "failed", attempts: 2, processing_errors: "boom")
      event.mark_as_processed!

      event.reload
      expect(event.status).to eq("processed")
      expect(event.processed_at).to be_present
      expect(event.processing_errors).to be_nil
    end
  end
end



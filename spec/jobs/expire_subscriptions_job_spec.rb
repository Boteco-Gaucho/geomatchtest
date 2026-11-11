require "rails_helper"

RSpec.describe ExpireSubscriptionsJob, type: :job do
  # Reuse the migrated Free plan; fall back to creating one if absent.
  let!(:free_plan)    { Plan.find_by(name: "Free") || create(:plan, :free) }
  let(:premium_plan)  { create(:plan, name: "Plus") }

  let!(:expired_user) do
    create(:user, plan: premium_plan, premium_until: 1.day.ago)
  end

  let!(:active_user) do
    create(:user, plan: premium_plan, premium_until: 10.days.from_now)
  end

  describe "#perform" do
    before { described_class.perform_now }

    context "with an expired premium user (premium_until in the past)" do
      it "downgrades the plan to Free" do
        expect(expired_user.reload.plan).to eq(free_plan)
      end

      it "sets premium_until to nil" do
        expect(expired_user.reload.premium_until).to be_nil
      end
    end

    context "with an active premium user (premium_until in the future)" do
      it "does not change the plan" do
        expect(active_user.reload.plan).to eq(premium_plan)
      end

      it "does not clear premium_until" do
        expect(active_user.reload.premium_until).not_to be_nil
      end
    end
  end
end

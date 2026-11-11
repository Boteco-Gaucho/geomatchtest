require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "associations" do
    # The User model has a before_validation callback that automatically assigns
    # the Free plan when plan is nil, so the association is effectively optional
    # from a validation standpoint (the callback prevents a nil plan from ever
    # reaching validation).
    it { is_expected.to belong_to(:plan).optional }
    it { is_expected.to have_many(:payments).dependent(:destroy) }
  end

  describe "validations" do
    # Skipped: plan presence is enforced via the set_free_plan callback,
    # not a classic Rails validator — Shoulda Matchers cannot prove it.
  end

  describe "callbacks" do
    it "sets free plan by default on create when plan is nil (if free exists)" do
      free_plan = Plan.find_by(name: "Free") || create(:plan, :free)
      new_user = build(:user, plan: nil)
      new_user.save!
      expect(new_user.plan).to eq(free_plan)
    end
  end

  describe "#premium?" do
    it "returns true when premium_until is in the future" do
      user.premium_until = 1.day.from_now
      expect(user.premium?).to be(true)
    end

    it "returns false when premium_until is nil or in the past" do
      user.premium_until = nil
      expect(user.premium?).to be(false)
      user.premium_until = 1.day.ago
      expect(user.premium?).to be(false)
    end
  end

  describe "#can_send_message?" do
    # Reuse the migrated Free plan; fall back to creating one only if absent.
    let!(:free_plan) { Plan.find_by(name: "Free") || create(:plan, :free) }

    context "with Free plan" do
      it "returns true when messages_count is below the limit of 3" do
        user = create(:user, plan: free_plan, messages_count: 2,
                             last_message_reset_at: 1.minute.ago)
        expect(user.can_send_message?).to be(true)
      end

      it "returns false when messages_count is at or above the limit of 3" do
        user = create(:user, plan: free_plan, messages_count: 3,
                             last_message_reset_at: 1.minute.ago)
        expect(user.can_send_message?).to be(false)
      end
    end

    context "with Plus plan" do
      # Use auto-sequenced code to avoid conflicts with migration-created 'plus' plan.
      let(:plus_plan) { create(:plan, name: "Plus") }

      it "returns true regardless of messages_count" do
        user = create(:user, plan: plus_plan, messages_count: 999)
        expect(user.can_send_message?).to be(true)
      end
    end

    context "with Gold plan" do
      let(:gold_plan) { create(:plan, name: "Gold") }

      it "returns true regardless of messages_count" do
        user = create(:user, plan: gold_plan, messages_count: 999)
        expect(user.can_send_message?).to be(true)
      end
    end
  end

  describe "#can_like?" do
    let!(:free_plan) { Plan.find_by(name: "Free") || create(:plan, :free) }

    context "with Free plan (no limit in features)" do
      it "returns true when likes_count is below the failsafe limit of 47" do
        user = create(:user, plan: free_plan, likes_count: 46,
                             last_like_reset_at: 1.minute.ago)
        expect(user.can_like?).to be(true)
      end

      it "returns false when likes_count reaches the failsafe limit of 47" do
        user = create(:user, plan: free_plan, likes_count: 47,
                             last_like_reset_at: 1.minute.ago)
        expect(user.can_like?).to be(false)
      end
    end

    context "with unlimited likes feature (e.g. Plus/Gold)" do
      let(:unlimited_plan) do
        create(:plan, name: "Plus", features: { "likes_right_unlimited" => true })
      end

      it "returns true regardless of likes_count" do
        user = create(:user, plan: unlimited_plan, likes_count: 999,
                             last_like_reset_at: 1.minute.ago)
        expect(user.can_like?).to be(true)
      end
    end

    context "with likes_right_limit feature" do
      let(:limited_plan) do
        create(:plan, name: "Plus", features: { "likes_right_limit" => 10 })
      end

      it "returns true when likes_count is below the plan limit" do
        user = create(:user, plan: limited_plan, likes_count: 9,
                             last_like_reset_at: 1.minute.ago)
        expect(user.can_like?).to be(true)
      end

      it "returns false when likes_count meets the plan limit" do
        user = create(:user, plan: limited_plan, likes_count: 10,
                             last_like_reset_at: 1.minute.ago)
        expect(user.can_like?).to be(false)
      end
    end
  end

  describe "#downgrade_to_free!" do
    # Reuse the migrated Free plan — no need to create a new one.
    let!(:free_plan)    { Plan.find_by(name: "Free") || create(:plan, :free) }
    let(:premium_plan)  { create(:plan, name: "Plus") }

    subject(:premium_user) { create(:user, plan: premium_plan, premium_until: 30.days.from_now) }

    it "resets the user's plan to Free" do
      premium_user.downgrade_to_free!
      expect(premium_user.reload.plan).to eq(free_plan)
    end

    it "sets premium_until to nil" do
      premium_user.downgrade_to_free!
      expect(premium_user.reload.premium_until).to be_nil
    end

    it "is a no-op when the Free plan does not exist" do
      Plan.where(name: "Free").delete_all
      expect { premium_user.downgrade_to_free! }.not_to raise_error
      expect(premium_user.reload.plan).to eq(premium_plan)
    end
  end
end

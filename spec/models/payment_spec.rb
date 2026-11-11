require "rails_helper"

RSpec.describe Payment, type: :model do
  subject(:payment) { build(:payment) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:plan) }
  end

  describe "state machine (AASM)" do
    it "starts in created state" do
      payment.save!
      expect(payment.state).to eq("created")
      expect(payment).to be_created
    end

    it "when approved, sets paid_at and updates user's plan" do
      old_plan = Plan.find_by(name: "Free") || create(:plan, :free)
      new_plan = create(:plan)
      user = create(:user, plan: old_plan)

      pay = Payment.create!(user: user, plan: new_plan)
      pay.approve!({})

      expect(pay.reload.state).to eq("approved")
      expect(user.reload.plan).to eq(new_plan)
    end

    it "mark_from_mercado_pago! transitions to approved based on mp status" do
      old_plan = Plan.find_by(name: "Free") || create(:plan, :free)
      new_plan = create(:plan)
      user = create(:user, plan: old_plan)
      pay = Payment.create!(user: user, plan: new_plan)

      mp_payment = { "status" => "approved", "id" => 123 }
      pay.approve!(mp_payment)

      expect(pay.reload.state).to eq("approved")
      expect(user.reload.plan).to eq(new_plan)
      expect(pay.mercado_pago_payment_id).to eq("123")
    end

    describe "same-plan renewal (extension)" do
      # Regression: before the fix, sync_user_plan_from_payment! had an early
      # return when user.plan_id == plan_id, silently skipping the extension.
      it "extends premium_until when the user renews the exact same plan" do
        plus_plan = create(:plan, name: "Plus", duration_days: 30)
        original_expiry = 2.days.from_now
        user = create(:user, plan: plus_plan, premium_until: original_expiry)

        payment = Payment.create!(user: user, plan: plus_plan)
        payment.approve!({})

        user.reload
        expect(user.plan).to eq(plus_plan)
        expect(user.premium_until).to be > original_expiry
        expect(user.premium_until).to be_within(5.seconds).of(Time.current + 30.days)
      end

      it "does not reset the user to Free when renewing a paid plan" do
        free_plan = Plan.find_by(name: "Free") || create(:plan, :free)
        plus_plan  = create(:plan, name: "Plus", duration_days: 30)
        user = create(:user, plan: plus_plan, premium_until: 2.days.from_now)

        payment = Payment.create!(user: user, plan: plus_plan)
        payment.approve!({})

        expect(user.reload.plan).not_to eq(free_plan)
      end
    end
  end
end



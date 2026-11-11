require "rails_helper"

RSpec.describe Plan, type: :model do
  subject(:plan) { build(:plan) }

  describe "associations" do
    it { is_expected.to have_many(:payments).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }

    it { is_expected.to validate_presence_of(:price_cents) }
    it { is_expected.to validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_presence_of(:price_currency) }

    it { is_expected.to validate_presence_of(:duration_days) }
    it { is_expected.to validate_numericality_of(:duration_days).only_integer.is_greater_than(0) }

    it { is_expected.to validate_presence_of(:features) }

    it "validates features is a hash" do
      plan.features = "not a hash"
      expect(plan).not_to be_valid
      expect(plan.errors[:features]).to include("must be a JSON object")
    end
  end

  describe "#feature_enabled?" do
    it "returns true when feature key is true" do
      plan.features = { "unlimited_likes" => true }
      expect(plan.feature_enabled?(:unlimited_likes)).to be(true)
    end

    it "returns false when feature key is missing or not true" do
      plan.features = { "unlimited_likes" => false }
      expect(plan.feature_enabled?(:unlimited_likes)).to be(false)
      expect(plan.feature_enabled?(:see_who_liked)).to be(false)
    end
  end

  describe "#feature_value" do
    it "returns the stored value" do
      plan.features = { "super_likes_per_day" => 5 }
      expect(plan.feature_value(:super_likes_per_day)).to eq(5)
    end

    it "returns default when missing" do
      plan.features = {}
      expect(plan.feature_value(:super_likes_per_day, default: 0)).to eq(0)
    end
  end
end



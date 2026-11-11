FactoryBot.define do
  factory :payment do
    association :plan
    user { association(:user, plan: plan) }
  end
end



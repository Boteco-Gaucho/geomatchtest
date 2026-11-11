FactoryBot.define do
  factory :coupon do
    code { "MyString" }
    description { "MyText" }
    discount_type { "MyString" }
    duration_days { 1 }
    plan_codes { "" }
    usage_limit { 1 }
    used_count { 1 }
    expires_at { "2026-07-03 15:59:17" }
    active { false }
  end
end

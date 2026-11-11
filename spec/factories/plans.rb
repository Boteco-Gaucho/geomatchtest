FactoryBot.define do
  factory :plan do
    sequence(:code) { |n| "premium_#{n}" }
    name { "Plano Premium" }

    price_cents { 2990 }
    price_currency { "BRL" }

    is_recommended { false }

    features do
      {
        "unlimited_likes" => true,
        "see_who_liked" => true,
        "super_likes_per_day" => 5
      }
    end

    duration_days { 30 }
    duration_months { 1 }
    active { true }
    description { Faker::Lorem.sentence }

    trait :recommended do
      is_recommended { true }
    end

    trait :free do
      code { "free" }
      name { "Free" }
      price_cents { 0 }
      duration_days { 36500 }
      duration_months { 1200 }
      features do
        {
          "unlimited_likes" => false,
          "see_who_liked" => false,
          "super_likes_per_day" => 0
        }
      end
    end
  end
end



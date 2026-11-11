FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    username { Faker::Name.first_name }

    association :plan

    trait :free_plan do
      association :plan, factory: %i[plan free]
    end
  end
end



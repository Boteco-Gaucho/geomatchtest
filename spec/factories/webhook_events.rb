FactoryBot.define do
  factory :webhook_event do
    source { "mercadopago" }
    external_id { SecureRandom.uuid }
    topic { "payment" }
    action { "payment.updated" }
    payload do
      {
        "type" => "payment",
        "data" => { "id" => Faker::Number.number(digits: 9).to_s }
      }
    end
    status { "pending" }
    attempts { 0 }
    processing_errors { nil }
    processed_at { nil }
  end
end



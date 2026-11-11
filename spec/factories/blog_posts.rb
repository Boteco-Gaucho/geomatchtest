FactoryBot.define do
  factory :blog_post do
    title { "MyString" }
    slug { "MyString" }
    excerpt { "MyText" }
    content { "MyText" }
    featured_image { "MyString" }
    blog_category { nil }
    published_at { "2026-06-21 12:29:33" }
    user { nil }
  end
end

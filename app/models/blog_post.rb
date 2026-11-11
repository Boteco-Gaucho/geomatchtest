class BlogPost < ApplicationRecord
  belongs_to :blog_category
  belongs_to :user

  validates :title, :slug, :content, presence: true
  validates :slug, uniqueness: true

  scope :published, -> { where("published_at IS NOT NULL AND published_at <= ?", Time.zone.now).order(published_at: :desc) }
  scope :by_category, ->(category_slug) { joins(:blog_category).where(blog_categories: { slug: category_slug }) }

  before_validation :generate_slug

  def published?
    published_at.present? && published_at <= Time.zone.now
  end

  private

  def generate_slug
    self.slug = title.parameterize if title.present? && slug.blank?
  end
end

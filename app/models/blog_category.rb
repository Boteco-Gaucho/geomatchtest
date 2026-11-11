class BlogCategory < ApplicationRecord
  has_many :blog_posts, dependent: :nullify

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :generate_slug

  private

  def generate_slug
    self.slug = name.parameterize if name.present? && slug.blank?
  end
end

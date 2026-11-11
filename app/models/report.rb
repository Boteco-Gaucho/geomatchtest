class Report < ApplicationRecord
  belongs_to :reporter, class_name: 'User', optional: true

  has_many_attached :photos

  validates :description, presence: true

  CATEGORIES = %w[harassment fake_profile spam inappropriate_content underage scam other].freeze

  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true

  scope :pending,  -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }

  def resolved?
    resolved_at.present?
  end

  def resolve!
    update!(resolved_at: Time.current)
  end
end

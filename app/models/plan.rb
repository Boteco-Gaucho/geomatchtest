class Plan < ApplicationRecord
  monetize :price_cents

  has_many :payments, dependent: :nullify
  has_many :users, dependent: :nullify

  before_validation :set_defaults

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price_currency, presence: true
  validates :duration_days, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :max_likes_per_day, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes para facilitar consultas
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :recommended, -> { where(is_recommended: true) }

  private

  def set_defaults
    self.has_boost      = false if has_boost.nil?
    self.has_incognito  = false if has_incognito.nil?
    self.active         = true  if active.nil?
    self.is_recommended = false if is_recommended.nil?
    self.max_likes_per_day ||= 50
    self.price_currency ||= 'BRL'
  end

  public

  # Soft delete - desativa o plano em vez de deletar
  def soft_delete
    update(active: false)
  end

  # Reativa um plano desativado
  def reactivate
    update(active: true)
  end

end



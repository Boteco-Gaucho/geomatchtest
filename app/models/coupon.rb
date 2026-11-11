class Coupon < ApplicationRecord
  has_many :user_coupons, dependent: :destroy
  has_many :users, through: :user_coupons

  validates :code, presence: true, uniqueness: true
  # Por enquanto só há um tipo de desconto: acesso premium gratuito por N dias.
  validates :discount_type, presence: true, inclusion: { in: %w[free_access] }
  validates :duration_days, presence: true, numericality: { greater_than: 0 },
                            if: -> { discount_type == 'free_access' }
  validates :plan_codes, presence: true, if: -> { discount_type == 'free_access' }
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validates :usage_limit, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Cupons ativos e ainda não expirados.
  scope :active, -> { where(active: true).where('expires_at IS NULL OR expires_at > ?', Time.current) }

  # Cupom disponível para uso: ativo, não expirado e dentro do limite global de usos.
  # usage_limit nil OU 0 = ilimitado (a restrição por usuário é feita via UserCoupon).
  def available?
    active? &&
      (expires_at.nil? || expires_at > Time.current) &&
      (usage_limit.nil? || usage_limit.zero? || used_count < usage_limit)
  end

  def increment_usage!
    increment!(:used_count)
  end
end

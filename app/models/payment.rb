class Payment < ApplicationRecord
  include PaymentStateMachine

  belongs_to :plan, optional: true
  belongs_to :user

  enum :payment_type, {
    plan_purchase:  'plan_purchase',
    one_off_message: 'one_off_message',
    admin_grant:    'admin_grant'        # Cortesia / ajuste manual pelo administrador
  }

  # Alias para que CheckoutController#create_one_off_message possa chamar payment.checkout_url
  alias_attribute :checkout_url, :mercado_pago_checkout_url

  scope :latest_first,          -> { order(created_at: :desc) }
  scope :approved,              -> { where(state: 'approved') }

  def amount
    plan&.price
  end

  def apply_premium!(fallback_days: 30)
    effective_days = plan.duration_days.presence || fallback_days

    now = Time.current
    base = [user.premium_until, now].compact.max
    user.update!(premium_until: base + effective_days.days)
  end
end



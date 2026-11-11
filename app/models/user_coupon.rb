class UserCoupon < ApplicationRecord
  belongs_to :user
  belongs_to :coupon

  # Garante que cada usuário só use um mesmo cupom uma única vez.
  validates :user_id, uniqueness: { scope: :coupon_id, message: "já usou este cupom" }
end

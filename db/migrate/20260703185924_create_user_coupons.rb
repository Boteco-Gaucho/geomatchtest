class CreateUserCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :user_coupons do |t|
      t.references :user, null: false, foreign_key: true
      t.references :coupon, null: false, foreign_key: true
      t.datetime :applied_at, null: false

      t.timestamps
    end
    add_index :user_coupons, [:user_id, :coupon_id], unique: true
  end
end

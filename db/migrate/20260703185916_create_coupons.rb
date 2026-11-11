class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.text :description
      t.string :discount_type, null: false
      t.integer :duration_days
      t.jsonb :plan_codes, default: [], null: false
      t.integer :usage_limit
      t.integer :used_count, default: 0
      t.datetime :expires_at
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :coupons, :code, unique: true
    add_index :coupons, :active
  end
end

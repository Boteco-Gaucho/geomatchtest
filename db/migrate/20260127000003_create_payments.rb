class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true
      t.references :plan, null: false, foreign_key: true

      t.string :state, null: false, default: "created"

      t.string :mercado_pago_preference_id
      t.string :mercado_pago_checkout_url
      t.string :mercado_pago_payment_id
      t.string :mercado_pago_merchant_order_id
      t.jsonb :mercado_pago_payload

      t.datetime :paid_at
      t.timestamps
    end

    add_index :payments, :state
    add_index :payments, :mercado_pago_preference_id
    add_index :payments, :mercado_pago_payment_id
  end
end



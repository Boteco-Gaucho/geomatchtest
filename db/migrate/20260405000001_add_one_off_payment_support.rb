class AddOneOffPaymentSupport < ActiveRecord::Migration[8.1]
  def change
    # Payments: payment_type para distinguir compra de plano vs. mensagem avulsa
    add_column :payments, :payment_type, :string, null: false, default: 'plan_purchase'
    add_index  :payments, :payment_type

    # Payments: plan_id passa a ser opcional (pagamentos avulsos não têm plano)
    change_column_null :payments, :plan_id, true

    # Users: saldo de créditos de mensagens avulsas
    add_column :users, :one_off_message_credits, :integer, default: 0, null: false
  end
end

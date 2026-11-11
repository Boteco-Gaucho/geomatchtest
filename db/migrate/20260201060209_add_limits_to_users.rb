class AddLimitsToUsers < ActiveRecord::Migration[8.1]
 def change
    # Controle de Likes (Plano Free)
    add_column :users, :likes_count, :integer, default: 0
    add_column :users, :last_like_reset_at, :datetime

    # Controle de Mensagens (Plano Gold)
    add_column :users, :messages_count, :integer, default: 0
    add_column :users, :last_message_reset_at, :datetime
  end
end
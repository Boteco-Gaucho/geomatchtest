class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # Referência ao usuário que recebe a notificação (Recipient)
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      
      # Referência ao usuário que causou a notificação (Actor)
      t.references :actor, null: false, foreign_key: { to_table: :users }
      
      # Referência polimórfica ao objeto que desencadeou a notificação (Like, Match, etc.)
      t.references :notifiable, polymorphic: true, null: false
      
      t.string :action
      t.datetime :read_at

      t.timestamps
    end
    
    # Adiciona um índice para consultas rápidas por destinatário e status de leitura
    add_index :notifications, [:recipient_id, :read_at]
  end
end

class CreateBlocks < ActiveRecord::Migration[8.1]
def change
    create_table :blocks do |t|
      # CORREÇÃO: Apontar explicitamente para a tabela 'users'
      t.references :blocker, null: false, foreign_key: { to_table: :users }
      t.references :blocked, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    # RECOMENDADO: Adicionar índice único para evitar bloquear a mesma pessoa 2x
    add_index :blocks, [:blocker_id, :blocked_id], unique: true
  end
end
class CreateSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :settings do |t|
      t.string  :key,   null: false
      t.integer :value, null: false
      t.timestamps
    end

    add_index :settings, :key, unique: true

    # Valor padrão: mensagem avulsa = R$ 1,99 (199 centavos)
    execute <<~SQL
      INSERT INTO settings (key, value, created_at, updated_at)
      VALUES ('one_off_message_price', 199, NOW(), NOW())
    SQL
  end
end

class CreateReactions < ActiveRecord::Migration[8.1]
  def change
    create_table :reactions do |t|
      t.references :message, null: false, foreign_key: true
      t.references :user,    null: false, foreign_key: true
      t.string     :emoji,   null: false

      t.timestamps
    end
    # Um único emoji por usuário por mensagem (toggle/replace)
    add_index :reactions, [:message_id, :user_id], unique: true
  end
end

class CreateFavorites < ActiveRecord::Migration[8.1]
  def change
    create_table :favorites do |t|
      t.references :user,           null: false, foreign_key: { to_table: :users }
      t.references :favorited_user, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :favorites, [:user_id, :favorited_user_id], unique: true
  end
end

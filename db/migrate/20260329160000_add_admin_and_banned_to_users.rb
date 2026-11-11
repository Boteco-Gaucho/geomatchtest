class AddAdminAndBannedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin,     :boolean,  default: false, null: false
    add_column :users, :banned_at, :datetime

    add_index :users, :admin
    add_index :users, :banned_at
  end
end

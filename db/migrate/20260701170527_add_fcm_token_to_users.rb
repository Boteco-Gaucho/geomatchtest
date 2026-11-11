class AddFcmTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :fcm_token, :string
    add_index :users, :fcm_token, unique: true
  end
end

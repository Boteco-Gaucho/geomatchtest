class AddApnsTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :apns_token, :string
  end
end

class AddMissingFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :interested_in, :string
    add_column :users, :hobbies, :string
  end
end

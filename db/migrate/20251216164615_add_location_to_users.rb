class AddLocationToUsers < ActiveRecord::Migration[8.1]
   def change
    add_index :users, [:latitude, :longitude] unless index_exists?(:users, [:latitude, :longitude])
  end
end

class AddLastLocationUpdatedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :last_location_updated_at, :datetime
    add_index  :users, :last_location_updated_at
  end
end

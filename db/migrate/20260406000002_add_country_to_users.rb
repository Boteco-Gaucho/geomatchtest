class AddCountryToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :country, :string, default: 'Brasil'
  end
end

class AddExtendedProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :education_level,      :string
    add_column :users, :occupation,           :string
    add_column :users, :political_interests,  :jsonb, default: []
  end
end

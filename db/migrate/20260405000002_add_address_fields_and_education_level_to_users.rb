class AddAddressFieldsAndEducationLevelToUsers < ActiveRecord::Migration[8.1]
  def up
    # Troca education_level de string para integer (necessário para usar enum no Rails)
    remove_column :users, :education_level
    add_column :users, :education_level, :integer

    # Campos de endereço detalhado (preenchidos via ViaCEP)
    add_column :users, :zip_code,      :string
    add_column :users, :street,        :string
    add_column :users, :neighborhood,  :string
    add_column :users, :city,          :string
    add_column :users, :state,         :string
  end

  def down
    remove_column :users, :zip_code
    remove_column :users, :street
    remove_column :users, :neighborhood
    remove_column :users, :city
    remove_column :users, :state
    remove_column :users, :education_level
    add_column :users, :education_level, :string
  end
end

class AddPhoneAndFixUsernameToUsers < ActiveRecord::Migration[8.1]
def up
    # 1. Adiciona o telefone
    add_column :users, :phone, :string

    # 2. Tenta remover o índice único do username se ele existir
    # Isso permite que varias pessoas tenham o nome "João", por exemplo.
    if index_exists?(:users, :username)
      remove_index :users, :username
      add_index :users, :username # Adiciona de volta, mas sem unique: true
    end
  end

  def down
    remove_column :users, :phone
    # Na volta, não vamos forçar unique para evitar erros de dados existentes
  end
end
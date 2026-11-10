# Editar perfil — "Lugares que eu curto", "O que você procura", "Mais sobre você" e
# "Estilo de vida" (opções em ProfileDetails). A profissão usa a coluna occupation que já
# existia. Todas opcionais: "Prefiro não informar" é gravado como escolha (ProfileDetails::NOT_INFORMED).
class AddProfileDetailsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :looking_for,     :string
    add_column :users, :height_cm,       :integer  # 0 = prefere não informar
    add_column :users, :zodiac_sign,     :string
    add_column :users, :languages,       :string, array: true, default: [], null: false
    add_column :users, :favorite_places, :string, array: true, default: [], null: false
    add_column :users, :drinking,        :string
    add_column :users, :smoking,         :string
    add_column :users, :exercise,        :string, array: true, default: [], null: false
    add_column :users, :pets,            :string
    add_column :users, :kids,            :string
  end
end

# Olho da tela "Explorar cidades" (/discover_3d/gallery): some só da busca por
# cidades. É separado do modo oculto do mapa (users.invisible) — cada botão
# esconde a pessoa num lugar.
#
# Idempotente, como as anteriores: em produção a coluna pode ser criada à mão antes
# do deploy. Enquanto ela não existe, o botão responde 503 e a galeria não filtra
# (User.city_search_hiding?).
class AddHiddenFromCitySearchToUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :hidden_from_city_search)

    add_column :users, :hidden_from_city_search, :boolean, default: false, null: false
  end

  def down
    remove_column :users, :hidden_from_city_search if column_exists?(:users, :hidden_from_city_search)
  end
end

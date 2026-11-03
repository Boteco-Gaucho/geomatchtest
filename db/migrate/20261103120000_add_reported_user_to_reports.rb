# "Sobre quem?" da tela Fazer uma denúncia: guarda o perfil denunciado (opcional).
# Antes, o user_id que o chat, o perfil, o swipe e o mapa mandam para
# /report_incident era descartado e a denúncia não dizia de quem era.
#
# Idempotente, como a do chat: em produção a coluna pode ser criada à mão antes do
# deploy. Enquanto ela não existe, a tela esconde o "Sobre quem?"
# (Report.reported_user_column?) em vez de quebrar.
# Sem foreign key, como reporter_id: se a conta denunciada for apagada, a denúncia
# fica (Report#reported_user volta nil).
class AddReportedUserToReports < ActiveRecord::Migration[8.1]
  def up
    add_column :reports, :reported_user_id, :bigint unless column_exists?(:reports, :reported_user_id)
    add_index :reports, :reported_user_id unless index_exists?(:reports, :reported_user_id)
  end

  def down
    remove_column :reports, :reported_user_id if column_exists?(:reports, :reported_user_id)
  end
end

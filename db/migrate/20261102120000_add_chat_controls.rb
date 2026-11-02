# Recursos do chat novo:
#   messages.edited_at           — "Editar" (o balão mostra "editada")
#   messages.hidden_for_user_ids — "Apagar para mim" e "Limpar conversa": somem só
#                                  para quem pediu; a outra pessoa mantém o histórico
#   matches.muted_by_user_ids    — "Silenciar notificações" da conversa
#   matches.distance_m           — distância quando a conexão aconteceu
#                                  ("Vocês se conectaram a menos de 300 m")
#
# Idempotente, como a de reply_to: em produção (Render free, sem Shell) as colunas
# podem ser criadas à mão antes — cada passo só roda se ainda faltar. Enquanto
# elas não existem, o código desliga esses recursos em vez de quebrar o chat
# (Message.chat_controls? / Match.chat_controls?).
class AddChatControls < ActiveRecord::Migration[8.1]
  def up
    add_column :messages, :edited_at, :datetime unless column_exists?(:messages, :edited_at)
    unless column_exists?(:messages, :hidden_for_user_ids)
      add_column :messages, :hidden_for_user_ids, :bigint, array: true, default: [], null: false
    end
    unless column_exists?(:matches, :muted_by_user_ids)
      add_column :matches, :muted_by_user_ids, :bigint, array: true, default: [], null: false
    end
    add_column :matches, :distance_m, :integer unless column_exists?(:matches, :distance_m)
  end

  def down
    remove_column :matches, :distance_m if column_exists?(:matches, :distance_m)
    remove_column :matches, :muted_by_user_ids if column_exists?(:matches, :muted_by_user_ids)
    remove_column :messages, :hidden_for_user_ids if column_exists?(:messages, :hidden_for_user_ids)
    remove_column :messages, :edited_at if column_exists?(:messages, :edited_at)
  end
end

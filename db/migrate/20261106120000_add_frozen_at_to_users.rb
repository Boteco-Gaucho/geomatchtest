# "Congelar conta" — oferecido na folha "Encerrar conta" de Meu Perfil, antes de apagar.
# Congelado: some da descoberta, do mapa e da página de perfil; tudo fica guardado.
# Entrar de novo (site ou app) descongela. Ver User#freeze_account!.
#
# Idempotente, como as anteriores: em produção a coluna é criada à mão
#   ALTER TABLE users ADD COLUMN IF NOT EXISTS frozen_at timestamp(6);
# Enquanto ela não existe, a opção de congelar não aparece (User.account_freezing?).
class AddFrozenAtToUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :frozen_at)

    add_column :users, :frozen_at, :datetime
  end

  def down
    remove_column :users, :frozen_at if column_exists?(:users, :frozen_at)
  end
end

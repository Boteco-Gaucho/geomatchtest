# "Esconder minha idade" (Gold) — tela Privacidade e localização (/privacidade).
#
# Idempotente, como as anteriores: em produção a coluna é criada à mão
#   ALTER TABLE users ADD COLUMN IF NOT EXISTS hide_age boolean NOT NULL DEFAULT false;
# Enquanto ela não existe, o interruptor responde 503 e as idades continuam
# aparecendo (User.age_hiding?).
class AddHideAgeToUsers < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:users, :hide_age)

    add_column :users, :hide_age, :boolean, default: false, null: false
  end

  def down
    remove_column :users, :hide_age if column_exists?(:users, :hide_age)
  end
end

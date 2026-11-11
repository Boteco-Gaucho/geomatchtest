class CreateAdminLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_logs do |t|
      t.bigint  :admin_id,    null: false
      t.string  :action,      null: false
      t.bigint  :target_id,   null: false
      t.string  :target_type, null: false, default: 'User'
      t.jsonb   :details,     null: false, default: {}

      t.timestamps
    end

    add_index :admin_logs, :admin_id
    add_index :admin_logs, [:target_type, :target_id]
    add_index :admin_logs, :action
    add_index :admin_logs, :created_at
  end
end

class CreateWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :webhook_events, id: :uuid do |t|
      t.string :source, default: 'mercadopago'
      t.string :external_id, index: true
      t.string :topic
      t.string :action
      t.jsonb :payload, null: false, default: {} 
      t.string :status, default: 'pending', index: true
      t.integer :attempts, default: 0
      t.text :processing_errors
      t.datetime :processed_at
      t.timestamps
    end

    add_index :webhook_events, [:status, :topic]
  end
end
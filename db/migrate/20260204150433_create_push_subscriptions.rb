class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.text :endpoint
      t.string :p256dh
      t.string :auth
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end

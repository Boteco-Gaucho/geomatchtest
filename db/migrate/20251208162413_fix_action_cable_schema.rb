class FixActionCableSchema < ActiveRecord::Migration[8.1]
  def change
    # Connections
    create_table :action_cable_internal_connections, if_not_exists: true do |t|
      t.string :identifier
      t.datetime :connected_at
    end
    add_index :action_cable_internal_connections, :id, unique: true, if_not_exists: true

    # Channels
    create_table :action_cable_internal_channels, if_not_exists: true do |t|
      t.bigint :connection_id
      t.string :channel_class
      t.string :identifier
    end
    add_index :action_cable_internal_channels, :id, unique: true, if_not_exists: true

    # Messages
    create_table :action_cable_internal_messages, if_not_exists: true do |t|
      t.bigint :channel_id
      t.jsonb :payload
      t.datetime :created_at
    end
    add_index :action_cable_internal_messages, :id, unique: true, if_not_exists: true
  end
end
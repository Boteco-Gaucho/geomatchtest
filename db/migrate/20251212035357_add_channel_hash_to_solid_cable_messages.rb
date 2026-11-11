class AddChannelHashToSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :solid_cable_messages, :channel_hash, :bigint
    add_index  :solid_cable_messages, :channel_hash
  end
end

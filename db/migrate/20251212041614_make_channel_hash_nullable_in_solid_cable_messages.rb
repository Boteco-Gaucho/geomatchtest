class MakeChannelHashNullableInSolidCableMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :solid_cable_messages, :channel_hash, true
  end
end

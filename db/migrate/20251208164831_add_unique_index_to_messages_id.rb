class AddUniqueIndexToMessagesId < ActiveRecord::Migration[8.1]
  def change
     add_index :messages, :id, unique: true, name: "index_messages_on_id"
  end
end

class AddAiModerationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ai_moderation_status, :string
    add_column :users, :ai_moderation_score, :float
    add_column :users, :ai_moderation_details, :jsonb
  end
end

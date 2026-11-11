class AddIsLikeToLikes < ActiveRecord::Migration[8.1]
  def change
    add_column :likes, :is_like, :boolean, default: true
  end
end

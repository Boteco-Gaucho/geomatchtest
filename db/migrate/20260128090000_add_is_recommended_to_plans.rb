class AddIsRecommendedToPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :is_recommended, :boolean, null: false, default: false
    add_index :plans, :is_recommended
  end
end



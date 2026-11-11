class AddCategoryToReports < ActiveRecord::Migration[8.1]
  CATEGORIES = %w[harassment fake_profile spam inappropriate_content underage scam other].freeze

  def change
    add_column :reports, :category, :string, default: 'other', null: false
    add_index  :reports, :category
  end
end

class CreateBlogCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
    end

    add_index :blog_categories, :slug, unique: true
  end
end

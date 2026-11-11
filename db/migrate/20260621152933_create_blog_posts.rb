class CreateBlogPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :blog_posts do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.text :content, null: false
      t.string :featured_image
      t.references :blog_category, null: false, foreign_key: true
      t.datetime :published_at
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :blog_posts, :slug, unique: true
    add_index :blog_posts, :published_at
  end
end

class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.references :user, null: false, foreign_key: true
      t.text :caption
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
    add_index :stories, [:latitude, :longitude]
  end
end
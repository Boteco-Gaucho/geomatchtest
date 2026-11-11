class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.text :description

      t.timestamps
    end
  end
end

class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.monetize :price,
                 amount: { null: false },
                 currency: { null: false, default: "BRL" }
      t.integer :duration_days, null: false
      t.boolean :active, null: false, default: true
      t.text :description
      t.jsonb :features, null: false, default: {}
      t.timestamps
    end

    add_index :plans, :code, unique: true
    add_index :plans, :active
    add_index :plans, :features, using: :gin
  end
end



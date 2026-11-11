class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :plan, foreign_key: true, index: true
  end
end



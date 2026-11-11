class CreateFreePlanAndSetDefaultForUsers < ActiveRecord::Migration[8.1]
  class MigrationPlan < ApplicationRecord
    self.table_name = "plans"
  end

  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  def up
    MigrationPlan.reset_column_information
    MigrationUser.reset_column_information

    free_attrs = {
      code: "free",
      name: "Free",
      price_cents: 0,
      price_currency: "BRL",
      duration_days: 36500,
      active: true,
      description: "Plano gratuito",
      features: {
        "list_liked" => false,
        "invisible_mode" => false,
        "list_liked_me" => false,
        "unlimited_messages" => false,
        "hide_age" => false
      }
    }

    free_plan = MigrationPlan.find_or_initialize_by(code: "free")
    free_plan.assign_attributes(free_attrs.except(:code))
    free_plan.save!

    MigrationUser.where(plan_id: nil).update_all(plan_id: free_plan.id)
  end
end



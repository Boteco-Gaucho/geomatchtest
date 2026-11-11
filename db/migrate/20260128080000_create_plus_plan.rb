class CreatePlusPlan < ActiveRecord::Migration[8.1]
  class MigrationPlan < ActiveRecord::Base
    self.table_name = "plans"
  end

  def up
    plus_attrs = {
      code: "plus",
      name: "Plus",
      price_cents: 2990,
      price_currency: "BRL",
      duration_days: 30,
      active: true,
      description: "Plano Plus",
      features: {
        "list_liked" => true,
        "invisible_mode" => true,
        "list_liked_me" => true,
        "unlimited_messages" => true,
        "hide_age" => true
      }
    }

    plan = MigrationPlan.find_or_initialize_by(code: plus_attrs[:code])
    plan.assign_attributes(plus_attrs.except(:code))
    plan.save!
  end

  def down
    MigrationPlan.where(code: "plus").delete_all
  end
end



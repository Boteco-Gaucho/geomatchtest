class AddRewindAndSearchByDistanceToPlans < ActiveRecord::Migration[8.1]
  def up
    ['gold', 'plus', 'free'].each do |code|
      plan = Plan.find_by(code: code)
      next unless plan

      is_gold = (code == 'gold')
      plan.features['rewind_profile']    = is_gold
      plan.features['search_by_distance'] = is_gold
      plan.save!
    end
  end

  def down
    Plan.all.each do |plan|
      if plan.features.key?('rewind_profile') || plan.features.key?('search_by_distance')
        plan.features.delete('rewind_profile')
        plan.features.delete('search_by_distance')
        plan.save!
      end
    end
  end
end

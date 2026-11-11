  class AddOnboardingCompletedToUsers < ActiveRecord::Migration[8.1]
    def change
      add_column :users, :onboarding_completed, :boolean, default: false, null: false
    end
  end

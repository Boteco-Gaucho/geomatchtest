class AddResolvedAtToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :resolved_at, :datetime
    add_index  :reports, :resolved_at
  end
end

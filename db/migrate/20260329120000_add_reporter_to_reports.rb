class AddReporterToReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :reports, :reporter, null: true, foreign_key: { to_table: :users }
  end
end

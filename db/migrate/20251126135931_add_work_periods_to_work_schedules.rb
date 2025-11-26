class AddWorkPeriodsToWorkSchedules < ActiveRecord::Migration[8.1]
  def change
    # Add JSONB column for flexible work periods
    # Format: [{ "start": "09:00", "end": "12:00" }, { "start": "13:00", "end": "17:00" }]
    add_column :work_schedules, :work_periods, :jsonb, default: []

    # Add index for JSONB queries (optional but recommended for performance)
    add_index :work_schedules, :work_periods, using: :gin

    # Migrate existing data: convert opening_time/closing_time to work_periods
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE work_schedules
          SET work_periods = jsonb_build_array(
            jsonb_build_object(
              'start', to_char(opening_time, 'HH24:MI'),
              'end', to_char(closing_time, 'HH24:MI')
            )
          )
          WHERE opening_time IS NOT NULL AND closing_time IS NOT NULL;
        SQL
      end
    end
  end
end

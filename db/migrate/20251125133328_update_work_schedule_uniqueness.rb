class UpdateWorkScheduleUniqueness < ActiveRecord::Migration[8.1]
  def change
    # DB-level constraint: only one active schedule per office per day
    add_index :work_schedules, [ :office_id, :day_of_week, :is_active ],
              unique: true,
              where: "is_active = true",
              name: "index_work_schedules_unique_active_per_office_day"
  end
end

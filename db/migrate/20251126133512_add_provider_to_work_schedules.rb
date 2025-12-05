class AddProviderToWorkSchedules < ActiveRecord::Migration[8.1]
  def change
    # Add provider reference
    add_reference :work_schedules, :provider, type: :uuid, foreign_key: { to_table: :users }

    # Remove old unique index (office + day + is_active)
    remove_index :work_schedules, name: "index_work_schedules_unique_active_per_office_day"

    # Add new unique index including provider (provider + office + day + is_active)
    add_index :work_schedules,
              [ :provider_id, :office_id, :day_of_week, :is_active ],
              unique: true,
              where: "is_active = true",
              name: "index_work_schedules_unique_active_per_provider_office_day"

    # Add composite indexes for common queries
    add_index :work_schedules, [ :provider_id, :day_of_week ]
    add_index :work_schedules, [ :provider_id, :office_id ]
  end
end

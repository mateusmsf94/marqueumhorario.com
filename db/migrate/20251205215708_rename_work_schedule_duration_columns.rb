class RenameWorkScheduleDurationColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :work_schedules, :appointment_duration_minutes, :slot_duration_minutes
    rename_column :work_schedules, :buffer_minutes_between_appointments, :slot_buffer_minutes
  end
end

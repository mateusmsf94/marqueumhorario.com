class CreateWorkSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :work_schedules, id: :uuid do |t|
      t.integer :day_of_week
      t.time :opening_time
      t.time :closing_time
      t.integer :appointment_duration_minutes
      t.integer :buffer_minutes_between_appointments
      t.boolean :is_active

      t.timestamps
    end
  end
end

require "securerandom"

class AddOfficeReferences < ActiveRecord::Migration[8.1]
  class MigrationOffice < ActiveRecord::Base
    self.table_name = "offices"
  end

  class MigrationAppointment < ActiveRecord::Base
    self.table_name = "appointments"
  end

  class MigrationWorkSchedule < ActiveRecord::Base
    self.table_name = "work_schedules"
  end

  class MigrationAvailabilityCalendar < ActiveRecord::Base
    self.table_name = "availability_calendars"
  end

  def up
    # Add office_id to appointments
    add_reference :appointments, :office, type: :uuid, foreign_key: true
    add_index :appointments, [ :office_id, :scheduled_at ]
    add_index :appointments, [ :office_id, :status ]

    # Add office_id to work_schedules
    add_reference :work_schedules, :office, type: :uuid, foreign_key: true
    add_index :work_schedules, [ :office_id, :day_of_week, :is_active ],
              name: "index_work_schedules_on_office_day_active"

    # Add office_id to availability_calendars
    add_reference :availability_calendars, :office, type: :uuid, foreign_key: true
    add_index :availability_calendars, [ :office_id, :period_start ]

    backfill_office_ids

    change_column_null :appointments, :office_id, false
    change_column_null :work_schedules, :office_id, false
    change_column_null :availability_calendars, :office_id, false
  end

  def down
    remove_index :appointments, [ :office_id, :scheduled_at ]
    remove_index :appointments, [ :office_id, :status ]
    remove_reference :appointments, :office, foreign_key: true

    remove_index :work_schedules, name: "index_work_schedules_on_office_day_active"
    remove_reference :work_schedules, :office, foreign_key: true

    remove_index :availability_calendars, [ :office_id, :period_start ]
    remove_reference :availability_calendars, :office, foreign_key: true
  end

  private

  def backfill_office_ids
    default_office_id = MigrationOffice.order(:created_at).pick(:id)

    unless default_office_id
      default_office_id = SecureRandom.uuid
      MigrationOffice.create!(
        id: default_office_id,
        name: "Default Office",
        time_zone: "UTC",
        is_active: true,
        created_at: Time.current,
        updated_at: Time.current
      )
    end

    MigrationAppointment.where(office_id: nil).update_all(office_id: default_office_id)
    MigrationWorkSchedule.where(office_id: nil).update_all(office_id: default_office_id)
    MigrationAvailabilityCalendar.where(office_id: nil).update_all(office_id: default_office_id)
  end
end

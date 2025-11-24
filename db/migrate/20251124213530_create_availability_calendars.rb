class CreateAvailabilityCalendars < ActiveRecord::Migration[8.1]
  def change
    create_table :availability_calendars, id: :uuid do |t|
      t.datetime :period_start
      t.datetime :period_end
      t.json :available_periods
      t.json :busy_periods

      t.timestamps
    end
  end
end

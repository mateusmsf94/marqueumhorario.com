class AddConfirmationFieldsToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_column :appointments, :confirmed_at, :datetime
    add_column :appointments, :declined_at, :datetime
    add_column :appointments, :decline_reason, :text

    add_index :appointments, :confirmed_at
    add_index :appointments, :declined_at
  end
end

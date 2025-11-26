class AddCustomerToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_reference :appointments, :customer, type: :uuid, foreign_key: { to_table: :users }

    # Index for customer's appointments
    add_index :appointments, [ :customer_id, :scheduled_at ]
    add_index :appointments, [ :customer_id, :status ]
  end
end

class AddProviderToAppointments < ActiveRecord::Migration[8.1]
  def change
    add_reference :appointments, :provider, type: :uuid, foreign_key: { to_table: :users }

    # Indexes for common queries
    add_index :appointments, [ :provider_id, :scheduled_at ]
    add_index :appointments, [ :provider_id, :status ]
    add_index :appointments, [ :provider_id, :office_id ]
  end
end

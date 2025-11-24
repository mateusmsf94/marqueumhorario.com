class CreateAppointments < ActiveRecord::Migration[8.1]
  def change
    create_table :appointments, id: :uuid do |t|
      t.datetime :scheduled_at, null: false
      t.string :title, null: false, limit: 255
      t.text :description
      t.string :status, null: false, default: "pending", limit: 50
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :appointments, :status
    add_index :appointments, :scheduled_at
  end
end

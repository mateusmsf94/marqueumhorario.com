class CreateOffices < ActiveRecord::Migration[8.1]
  def change
    create_table :offices, id: :uuid do |t|
      t.string :name, null: false, limit: 255
      t.text :description
      t.string :time_zone, null: false, default: 'UTC', limit: 100
      t.boolean :is_active, null: false, default: true

      # Address fields
      t.string :address, limit: 500
      t.string :city, limit: 100
      t.string :state, limit: 50
      t.string :zip_code, limit: 20

      # Geocoding fields (PostGIS-ready: decimal precision matches ST_Point accuracy)
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      t.timestamps
    end

    # Indexes for common queries
    add_index :offices, :is_active
    add_index :offices, :city
    add_index :offices, [ :latitude, :longitude ]
    add_index :offices, :name
  end
end

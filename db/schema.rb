# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_25_133328) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "appointments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "lock_version", default: 0, null: false
    t.uuid "office_id", null: false
    t.datetime "scheduled_at", null: false
    t.string "status", limit: 50, default: "pending", null: false
    t.string "title", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["office_id", "scheduled_at"], name: "index_appointments_on_office_id_and_scheduled_at"
    t.index ["office_id", "status"], name: "index_appointments_on_office_id_and_status"
    t.index ["office_id"], name: "index_appointments_on_office_id"
    t.index ["scheduled_at"], name: "index_appointments_on_scheduled_at"
    t.index ["status"], name: "index_appointments_on_status"
  end

  create_table "availability_calendars", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.json "available_periods"
    t.json "busy_periods"
    t.datetime "created_at", null: false
    t.uuid "office_id", null: false
    t.datetime "period_end"
    t.datetime "period_start"
    t.datetime "updated_at", null: false
    t.index ["office_id", "period_start"], name: "index_availability_calendars_on_office_id_and_period_start"
    t.index ["office_id"], name: "index_availability_calendars_on_office_id"
  end

  create_table "offices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address", limit: 500
    t.string "city", limit: 100
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", limit: 255, null: false
    t.string "state", limit: 50
    t.string "time_zone", limit: 100, default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.string "zip_code", limit: 20
    t.index ["city"], name: "index_offices_on_city"
    t.index ["is_active"], name: "index_offices_on_is_active"
    t.index ["latitude", "longitude"], name: "index_offices_on_latitude_and_longitude"
    t.index ["name"], name: "index_offices_on_name"
  end

  create_table "work_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "appointment_duration_minutes"
    t.integer "buffer_minutes_between_appointments"
    t.time "closing_time"
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.boolean "is_active"
    t.uuid "office_id", null: false
    t.time "opening_time"
    t.datetime "updated_at", null: false
    t.index ["office_id", "day_of_week", "is_active"], name: "index_work_schedules_on_office_day_active"
    t.index ["office_id", "day_of_week", "is_active"], name: "index_work_schedules_unique_active_per_office_day", unique: true, where: "(is_active = true)"
    t.index ["office_id"], name: "index_work_schedules_on_office_id"
  end

  add_foreign_key "appointments", "offices"
  add_foreign_key "availability_calendars", "offices"
  add_foreign_key "work_schedules", "offices"
end

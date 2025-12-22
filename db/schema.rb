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

ActiveRecord::Schema[8.1].define(version: 2025_12_22_212842) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "appointments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.uuid "customer_id"
    t.text "decline_reason"
    t.datetime "declined_at"
    t.text "description"
    t.integer "duration_minutes", default: 50, null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "office_id", null: false
    t.uuid "provider_id"
    t.datetime "scheduled_at", null: false
    t.string "status", limit: 50, default: "pending", null: false
    t.string "title", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_at"], name: "index_appointments_on_confirmed_at"
    t.index ["customer_id", "scheduled_at"], name: "index_appointments_on_customer_id_and_scheduled_at"
    t.index ["customer_id", "status"], name: "index_appointments_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["declined_at"], name: "index_appointments_on_declined_at"
    t.index ["office_id", "scheduled_at"], name: "index_appointments_on_office_id_and_scheduled_at"
    t.index ["office_id", "status"], name: "index_appointments_on_office_id_and_status"
    t.index ["office_id"], name: "index_appointments_on_office_id"
    t.index ["provider_id", "office_id"], name: "index_appointments_on_provider_id_and_office_id"
    t.index ["provider_id", "scheduled_at"], name: "index_appointments_on_provider_id_and_scheduled_at"
    t.index ["provider_id", "status"], name: "index_appointments_on_provider_id_and_status"
    t.index ["provider_id"], name: "index_appointments_on_provider_id"
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

  create_table "office_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.uuid "office_id", null: false
    t.string "role", limit: 50, default: "member", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["office_id", "is_active"], name: "index_office_memberships_on_office_id_and_is_active"
    t.index ["office_id"], name: "index_office_memberships_on_office_id"
    t.index ["user_id", "is_active"], name: "index_office_memberships_on_user_id_and_is_active"
    t.index ["user_id", "office_id"], name: "index_office_memberships_unique_user_office", unique: true
    t.index ["user_id"], name: "index_office_memberships_on_user_id"
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

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "bio"
    t.string "cpf", limit: 11
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip", limit: 50
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "first_name", limit: 100, null: false
    t.string "last_name", limit: 100, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip", limit: 50
    t.string "phone", limit: 20
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token", limit: 255
    t.integer "sign_in_count", default: 0, null: false
    t.string "slug", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["cpf"], name: "index_users_on_cpf", unique: true, where: "(cpf IS NOT NULL)"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_name", "first_name"], name: "index_users_on_last_name_and_first_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  create_table "work_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.time "closing_time"
    t.datetime "created_at", null: false
    t.integer "day_of_week"
    t.boolean "is_active"
    t.uuid "office_id", null: false
    t.time "opening_time"
    t.uuid "provider_id"
    t.integer "slot_buffer_minutes"
    t.integer "slot_duration_minutes"
    t.datetime "updated_at", null: false
    t.jsonb "work_periods", default: []
    t.index ["office_id", "day_of_week", "is_active"], name: "index_work_schedules_on_office_day_active"
    t.index ["office_id"], name: "index_work_schedules_on_office_id"
    t.index ["provider_id", "day_of_week"], name: "index_work_schedules_on_provider_id_and_day_of_week"
    t.index ["provider_id", "office_id", "day_of_week", "is_active"], name: "index_work_schedules_unique_active_per_provider_office_day", unique: true, where: "(is_active = true)"
    t.index ["provider_id", "office_id"], name: "index_work_schedules_on_provider_id_and_office_id"
    t.index ["provider_id"], name: "index_work_schedules_on_provider_id"
    t.index ["work_periods"], name: "index_work_schedules_on_work_periods", using: :gin
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "appointments", "offices"
  add_foreign_key "appointments", "users", column: "customer_id"
  add_foreign_key "appointments", "users", column: "provider_id"
  add_foreign_key "availability_calendars", "offices"
  add_foreign_key "office_memberships", "offices"
  add_foreign_key "office_memberships", "users"
  add_foreign_key "work_schedules", "offices"
  add_foreign_key "work_schedules", "users", column: "provider_id"
end

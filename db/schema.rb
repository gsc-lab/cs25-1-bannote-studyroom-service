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

ActiveRecord::Schema[8.0].define(version: 2025_11_23_140521) do
  create_table "departments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_departments_on_code", unique: true
  end

  create_table "reservation_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "reservation_id", null: false
    t.bigint "user_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reservation_id", "user_code"], name: "index_reservation_users_on_reservation_id_and_user_code", unique: true
    t.index ["reservation_id"], name: "index_reservation_users_on_reservation_id"
    t.index ["user_code"], name: "index_reservation_users_on_user_code"
  end

  create_table "reservations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "purpose", null: false
    t.integer "priority", null: false
    t.datetime "deleted_at"
    t.string "code", null: false
    t.string "created_by"
    t.string "deleted_by"
    t.json "user_codes"
    t.integer "status", default: 1
    t.index ["code"], name: "index_reservations_on_code", unique: true
    t.index ["room_id"], name: "index_reservations_on_room_id"
  end

  create_table "room_exceptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.date "holiday_date", null: false
    t.string "reason", limit: 100
    t.string "opening_time"
    t.string "closing_time"
    t.bigint "created_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["holiday_date"], name: "index_room_exceptions_on_holiday_date"
    t.index ["room_id"], name: "index_room_exceptions_on_room_id"
  end

  create_table "room_operating_hours", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.integer "day_of_week", limit: 1, null: false
    t.string "opening_time", null: false
    t.string "closing_time", null: false
    t.string "day_maximum_time"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by"
    t.bigint "updated_by"
    t.bigint "deleted_by"
    t.index ["day_of_week"], name: "index_room_operating_hours_on_day_of_week"
    t.index ["room_id"], name: "index_room_operating_hours_on_room_id"
  end

  create_table "rooms", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "maximum_member"
    t.integer "status"
    t.integer "capacity"
    t.bigint "created_by"
    t.string "department_code"
    t.string "department_name"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_rooms_on_deleted_at"
  end

  add_foreign_key "reservations", "rooms"
  add_foreign_key "room_exceptions", "rooms"
  add_foreign_key "room_operating_hours", "rooms"
end

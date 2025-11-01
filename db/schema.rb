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

ActiveRecord::Schema[8.0].define(version: 2025_11_01_122012) do
  create_table "reservations", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "group_id", null: false
    t.bigint "link_id"
    t.string "purpose", null: false
    t.integer "priority", null: false
    t.bigint "created_by", null: false
    t.bigint "updated_by"
    t.bigint "deleted_by"
    t.datetime "deleted_at"
    t.bigint "user_id"
    t.string "code", null: false
    t.index ["code"], name: "index_reservations_on_code", unique: true
    t.index ["group_id"], name: "index_reservations_on_group_id"
    t.index ["link_id"], name: "index_reservations_on_link_id"
    t.index ["room_id"], name: "index_reservations_on_room_id"
  end

  create_table "room_exceptions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.date "exception_date", null: false
    t.string "reason", limit: 100
    t.datetime "opening_time"
    t.datetime "closing_time"
    t.bigint "created_by", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["exception_date"], name: "index_room_exceptions_on_exception_date"
    t.index ["room_id"], name: "index_room_exceptions_on_room_id"
  end

  create_table "room_operating_hours", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.integer "day_of_week", limit: 1, null: false
    t.datetime "opening_time"
    t.datetime "closing_time"
    t.datetime "day_maximum_time"
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
    t.string "department_name"
    t.string "department_code"
  end

  add_foreign_key "reservations", "rooms"
  add_foreign_key "room_exceptions", "rooms"
  add_foreign_key "room_operating_hours", "rooms"
end

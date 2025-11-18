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

ActiveRecord::Schema[8.1].define(version: 2025_11_18_100700) do
  create_table "players", primary_key: "player_id", id: :bigint, default: nil, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.bigint "exp"
    t.integer "icon"
    t.integer "is_init", limit: 2, default: 0
    t.integer "level"
    t.string "nickname"
    t.datetime "offline_at"
    t.datetime "online_at"
    t.integer "real_server_id"
    t.integer "sex"
    t.integer "show_server_id"
    t.datetime "updated_at", null: false
    t.integer "vip_level"
  end
end

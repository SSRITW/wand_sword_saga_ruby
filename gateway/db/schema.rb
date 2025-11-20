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

ActiveRecord::Schema[8.1].define(version: 2025_11_16_122419) do
  create_table "account_player_infos", primary_key: ["account_id", "show_server_id"], charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.bigint "player_id", null: false
    t.integer "player_level", default: 1, null: false
    t.string "player_name", default: "", null: false
    t.integer "real_server_id", null: false
    t.integer "show_server_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "accounts", primary_key: "account_id", id: :bigint, default: nil, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "account_name", null: false
    t.datetime "created_at", null: false
    t.integer "platform_id", null: false
    t.integer "platform_type", null: false
    t.datetime "updated_at", null: false
    t.index ["account_name"], name: "index_accounts_on_account_name", unique: true
  end

  create_table "game_servers", primary_key: "show_server_id", id: :integer, default: nil, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "flag", default: "[]"
    t.string "name", null: false
    t.integer "open_time", default: 0
    t.integer "rcmd_status", default: 0
    t.integer "real_server_id", null: false
    t.integer "svr_status", default: 0
    t.datetime "updated_at", null: false
  end
end

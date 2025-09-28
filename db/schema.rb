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

ActiveRecord::Schema[8.0].define(version: 2) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "board_games", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "min_players", null: false
    t.integer "max_players", null: false
    t.integer "min_playing_time"
    t.integer "max_playing_time"
    t.decimal "rating", precision: 3, scale: 2
    t.timestamptz "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.timestamptz "updated_at", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["name"], name: "idx_board_games_name"
    t.index ["rating"], name: "idx_board_games_rating"
    t.check_constraint "max_players >= min_players", name: "board_games_check"
    t.check_constraint "max_playing_time >= min_playing_time", name: "board_games_check1"
    t.check_constraint "min_players > 0", name: "board_games_min_players_check"
    t.check_constraint "min_playing_time > 0", name: "board_games_min_playing_time_check"
    t.check_constraint "rating >= 0::numeric AND rating <= 10::numeric", name: "board_games_rating_check"
  end

  create_table "extensions", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "board_game_id", null: false
    t.integer "min_players"
    t.integer "max_players"
    t.integer "min_playing_time"
    t.integer "max_playing_time"
    t.decimal "rating", precision: 3, scale: 2
    t.timestamptz "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.timestamptz "updated_at", default: -> { "CURRENT_TIMESTAMP" }
    t.index ["board_game_id"], name: "idx_extensions_board_game_id"
    t.index ["name"], name: "idx_extensions_name"
    t.check_constraint "max_players >= min_players", name: "extensions_check"
    t.check_constraint "max_playing_time >= min_playing_time", name: "extensions_check1"
    t.check_constraint "min_players > 0", name: "extensions_min_players_check"
    t.check_constraint "min_playing_time > 0", name: "extensions_min_playing_time_check"
    t.check_constraint "rating >= 0::numeric AND rating <= 10::numeric", name: "extensions_rating_check"
  end

  add_foreign_key "extensions", "board_games", name: "extensions_board_game_id_fkey", on_delete: :cascade
end

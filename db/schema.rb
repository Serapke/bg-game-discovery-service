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

ActiveRecord::Schema[8.0].define(version: 2025_12_02_172319) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "bgg_board_game_associations", force: :cascade do |t|
    t.bigint "board_game_id", null: false
    t.bigint "bgg_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["bgg_id"], name: "index_bgg_board_game_associations_on_bgg_id", unique: true
    t.index ["board_game_id", "bgg_id"], name: "index_bgg_associations_on_board_game_and_bgg_id", unique: true
    t.index ["board_game_id"], name: "index_bgg_board_game_associations_on_board_game_id"
    t.check_constraint "bgg_id > 0", name: "check_bgg_id_positive"
  end

  create_table "board_game_relations", force: :cascade do |t|
    t.bigint "source_game_id", null: false
    t.bigint "target_game_id", null: false
    t.string "relation_type", limit: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_game_id", "target_game_id", "relation_type"], name: "idx_bg_relations_unique", unique: true
    t.index ["target_game_id", "source_game_id", "relation_type"], name: "idx_bg_relations_reverse"
    t.check_constraint "source_game_id <> target_game_id", name: "prevent_self_relation"
  end

  create_table "board_games", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.integer "min_players", null: false
    t.integer "max_players", null: false
    t.integer "min_playing_time"
    t.integer "max_playing_time"
    t.decimal "rating", precision: 3, scale: 2
    t.timestamptz "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.timestamptz "updated_at", default: -> { "CURRENT_TIMESTAMP" }
    t.decimal "difficulty_score", precision: 3, scale: 2
    t.integer "year_published", null: false
    t.integer "rating_count"
    t.index ["name"], name: "idx_board_games_name"
    t.index ["rating"], name: "idx_board_games_rating"
    t.index ["rating_count"], name: "idx_board_games_rating_count"
    t.check_constraint "max_players >= min_players", name: "board_games_check"
    t.check_constraint "max_playing_time >= min_playing_time", name: "board_games_check1"
    t.check_constraint "min_players > 0", name: "board_games_min_players_check"
    t.check_constraint "min_playing_time > 0", name: "board_games_min_playing_time_check"
    t.check_constraint "rating >= 0::numeric AND rating <= 10::numeric", name: "board_games_rating_check"
    t.check_constraint "rating_count >= 0", name: "board_games_rating_count_check"
  end

  create_table "board_games_game_categories", id: false, force: :cascade do |t|
    t.bigint "board_game_id", null: false
    t.bigint "game_category_id", null: false
    t.index ["board_game_id", "game_category_id"], name: "idx_on_board_game_id_game_category_id_72511a3062"
    t.index ["game_category_id", "board_game_id"], name: "idx_on_game_category_id_board_game_id_87cc6e2be1"
  end

  create_table "board_games_game_types", id: false, force: :cascade do |t|
    t.bigint "board_game_id", null: false
    t.bigint "game_type_id", null: false
    t.integer "rank"
    t.index ["board_game_id", "game_type_id"], name: "index_board_games_game_types_on_board_game_id_and_game_type_id"
    t.index ["game_type_id", "board_game_id"], name: "index_board_games_game_types_on_game_type_id_and_board_game_id"
    t.check_constraint "rank > 0", name: "board_games_game_types_rank_check"
  end

  create_table "game_categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_game_categories_on_name", unique: true
  end

  create_table "game_types", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_game_types_on_name", unique: true
  end

  add_foreign_key "bgg_board_game_associations", "board_games", on_delete: :cascade
  add_foreign_key "board_game_relations", "board_games", column: "source_game_id", on_delete: :cascade
  add_foreign_key "board_game_relations", "board_games", column: "target_game_id", on_delete: :cascade
end

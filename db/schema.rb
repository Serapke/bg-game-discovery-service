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

ActiveRecord::Schema[8.0].define(version: 2026_07_14_130000) do
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
    t.string "image_url"
    t.string "thumbnail_url"
    t.text "description"
    t.integer "best_min_players"
    t.integer "best_max_players"
    t.index ["name"], name: "idx_board_games_name"
    t.index ["rating"], name: "idx_board_games_rating"
    t.index ["rating_count"], name: "idx_board_games_rating_count"
    t.check_constraint "best_max_players IS NULL OR best_min_players IS NOT NULL AND best_max_players >= best_min_players", name: "board_games_best_max_players_gte_min"
    t.check_constraint "best_min_players IS NULL OR best_min_players > 0", name: "board_games_best_min_players_positive"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.bigint "board_game_id", null: false
    t.string "youtube_video_id", null: false
    t.string "link", null: false
    t.string "title"
    t.string "category"
    t.string "language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "duration_seconds"
    t.bigint "view_count"
    t.bigint "like_count"
    t.bigint "comment_count"
    t.string "thumbnail_url"
    t.datetime "enriched_at"
    t.index ["board_game_id", "youtube_video_id"], name: "idx_videos_unique_per_game", unique: true
  end

  add_foreign_key "bgg_board_game_associations", "board_games", on_delete: :cascade
  add_foreign_key "board_game_relations", "board_games", column: "source_game_id", on_delete: :cascade
  add_foreign_key "board_game_relations", "board_games", column: "target_game_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "videos", "board_games", on_delete: :cascade
end

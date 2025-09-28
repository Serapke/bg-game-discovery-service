class CreateExtensions < ActiveRecord::Migration[7.0]
  def change
    create_table :extensions do |t|
      t.string :name, null: false, limit: 255
      t.references :board_game, null: false, foreign_key: { on_delete: :cascade }
      t.integer :min_players
      t.integer :max_players
      t.integer :min_playing_time
      t.integer :max_playing_time
      t.decimal :rating, precision: 3, scale: 2

      t.timestamps
    end

    add_check_constraint :extensions, "min_players > 0", name: "extensions_min_players_check"
    add_check_constraint :extensions, "max_players >= min_players", name: "extensions_max_players_check"
    add_check_constraint :extensions, "min_playing_time > 0", name: "extensions_min_playing_time_check"
    add_check_constraint :extensions, "max_playing_time >= min_playing_time", name: "extensions_max_playing_time_check"
    add_check_constraint :extensions, "rating >= 0 AND rating <= 10", name: "extensions_rating_check"

    add_index :extensions, :board_game_id
    add_index :extensions, :name
  end
end
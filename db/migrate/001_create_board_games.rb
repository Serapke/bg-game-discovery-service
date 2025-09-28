class CreateBoardGames < ActiveRecord::Migration[7.0]
  def change
    create_table :board_games do |t|
      t.string :name, null: false, limit: 255
      t.integer :min_players, null: false
      t.integer :max_players, null: false
      t.integer :min_playing_time
      t.integer :max_playing_time
      t.decimal :rating, precision: 3, scale: 2

      t.timestamps
    end

    add_check_constraint :board_games, "min_players > 0", name: "board_games_min_players_check"
    add_check_constraint :board_games, "max_players >= min_players", name: "board_games_max_players_check"
    add_check_constraint :board_games, "min_playing_time > 0", name: "board_games_min_playing_time_check"
    add_check_constraint :board_games, "max_playing_time >= min_playing_time", name: "board_games_max_playing_time_check"
    add_check_constraint :board_games, "rating >= 0 AND rating <= 10", name: "board_games_rating_check"

    add_index :board_games, :name
    add_index :board_games, :rating
  end
end
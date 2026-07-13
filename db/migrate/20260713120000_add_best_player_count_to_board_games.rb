class AddBestPlayerCountToBoardGames < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games, :best_min_players, :integer
    add_column :board_games, :best_max_players, :integer

    add_check_constraint :board_games,
      "best_min_players IS NULL OR best_min_players > 0",
      name: "board_games_best_min_players_positive"
    add_check_constraint :board_games,
      "best_max_players IS NULL OR (best_min_players IS NOT NULL AND best_max_players >= best_min_players)",
      name: "board_games_best_max_players_gte_min"
  end
end

class AddRankToBoardGamesGameTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games_game_types, :rank, :integer
    add_check_constraint :board_games_game_types, "rank > 0", name: "board_games_game_types_rank_check"
  end
end

class RemoveGameTypeFromBoardGames < ActiveRecord::Migration[8.0]
  def change
    remove_column :board_games, :game_type, :string
  end
end

class AddDifficultyScoreToBoardGames < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games, :difficulty_score, :decimal, precision: 3, scale: 2
  end
end

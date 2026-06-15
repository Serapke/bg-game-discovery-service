class AddDescriptionToBoardGames < ActiveRecord::Migration[8.0]
  def change
    add_column :board_games, :description, :text
  end
end
